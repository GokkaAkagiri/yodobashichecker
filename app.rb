require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader' if development?
require 'active_record'
require 'sqlite3'
require 'json'
require_relative 'scraper'
require_relative 'models/product'
require_relative 'models/price_history'
require_relative 'models/setting'
require_relative 'main' # send_discord_notificationを利用するため

# タイムゾーンを日本時間に設定
require 'active_support/core_ext/time/zones'
Time.zone = 'Tokyo'
ActiveRecord.default_timezone = :local

# DB接続設定
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/database.sqlite3'
)

# サーバー設定
set :public_folder, 'public' # /public 以下のファイルを静的ファイルとして配信
set :port, 4567
set :bind, '0.0.0.0' # Dockerコンテナ外からアクセスするために必要

# GET / : トップページ (public/index.html) を返す
get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

# GET /api/products : 登録されている全商品と、その最新価格、価格推移グラフ用データを返す
get '/api/products' do
  # N+1問題(JavaのJPAでもよくある、関連テーブルをループで引いてしまう問題)を防ぐため includes を使用
  products = Product.includes(:price_histories).all

  response_data = products.map do |product|
    latest_history = product.latest_price_history
    histories = product.price_histories.order(created_at: :asc)

    initial_history = product.price_histories.order(created_at: :asc).first
    initial_price = initial_history ? initial_history.effective_price : (latest_history ? latest_history.effective_price : 0)
    current_price = latest_history ? latest_history.effective_price : 0
    discount_rate = initial_price > 0 ? (((initial_price - current_price).to_f / initial_price) * 100).round(1) : 0

    {
      id: product.id,
      name: product.name,
      url: product.url,
      target_price: product.target_price,
      latest_price: current_price,
      latest_point_rate: latest_history ? latest_history.point_rate : nil,
      stock_status: latest_history ? (latest_history.stock_status || "情報なし") : "情報なし",
      discount_rate: discount_rate,
      initial_price: initial_price,
      updated_at: latest_history ? latest_history.created_at.strftime("%Y/%m/%d %H:%M") : nil,
      chart_data: histories.map do |h| 
        {
          x: h.created_at.iso8601, # ISO8601形式で日付を渡す(JS側でフィルタやフォーマットしやすいように)
          y: h.effective_price,
          label: h.created_at.strftime("%Y/%m/%d %H:%M")
        }
      end
    }
  end

  json response_data
end

# POST /api/products : 新しい商品を登録する
post '/api/products' do
  # 送信されたJSONボディを解析
  request.body.rewind
  payload = JSON.parse(request.body.read)

  url = payload['url']

  if url.nil? || url.empty?
    status 400
    return json({ error: "URLは必須です" })
  end

  product = Product.find_by(url: url)
  if product
    status 400
    return json({ error: 'この商品は既に登録されています' })
  end

  # スクレイピングして初期データを取得
  scraper = YodobashiScraper.new
  scraped_data = scraper.scrape(url)
  scraper.close
  
  unless scraped_data
    status 400
    return json({ error: 'データの取得に失敗しました。URLを確認してください。' })
  end

  # 10%OFFの目標価格を計算 (1の位切り捨て: 例 11115 -> 11110)
  default_target = 0
  if scraped_data[:effective_price] && scraped_data[:effective_price] > 0
    calculated = scraped_data[:effective_price] * 0.9
    default_target = (calculated / 10).floor * 10
  end

  product = Product.create!(
    name: scraped_data[:name],
    url: url,
    target_price: default_target
  )

  # 初期価格履歴を作成
  product.price_histories.create!(
    price: scraped_data[:price],
    point_rate: scraped_data[:point_rate],
    effective_price: scraped_data[:effective_price],
    stock_status: scraped_data[:stock_status],
    has_successor: scraped_data[:has_successor],
    successor_info: scraped_data[:successor_info]
  )

  status 201
  json({ message: "登録しました", product: product })
end

# PUT /api/products/:id : 商品の編集 (目標価格の変更)
put '/api/products/:id' do
  request.body.rewind
  payload = JSON.parse(request.body.read)
  
  product = Product.find_by(id: params[:id])
  if product.nil?
    status 404
    return json({ error: "商品が見つかりません" })
  end

  # 商品名と目標価格を更新
  product.update!(
    name: payload['name'] || product.name,
    target_price: payload['target_price'].to_i
  )

  json({ message: "更新しました", product: product })
end

# DELETE /api/products/:id : 商品の削除
delete '/api/products/:id' do
  product = Product.find_by(id: params[:id])
  if product.nil?
    status 404
    return json({ error: "商品が見つかりません" })
  end

  # 関連する price_histories も一緒に削除される(依存関係の設定によるが、念のため手動で消すか、あるいはそのまま消す)
  product.price_histories.destroy_all
  product.destroy

  json({ message: "削除しました" })
end

# POST /api/products/:id/scrape : 指定した商品を手動で即時スクレイピングする
post '/api/products/:id/scrape' do
  product = Product.find_by(id: params[:id])
  if product.nil?
    status 404
    return json({ error: "商品が見つかりません" })
  end

  scraper = YodobashiScraper.new
  begin
    data = scraper.scrape(product.url)
    if data
      # 通知判定と保存 (main.rbの共通メソッドを呼び出し)
      check_and_notify(product, data, true)

      json({ message: "価格情報を更新しました", data: data })
    else
      status 500
      json({ error: "価格情報の取得に失敗しました(サイト側の変更やブロックの可能性があります)" })
    end
  rescue => e
    status 500
    json({ error: "スクレイピング中にエラーが発生しました: #{e.message}" })
  ensure
    scraper.close
  end
end

# POST /api/products/bulk : URLの一括登録（非同期処理）
post '/api/products/bulk' do
  request.body.rewind
  payload = JSON.parse(request.body.read)
  urls = payload['urls']

  if urls.nil? || !urls.is_a?(Array) || urls.empty?
    status 400
    return json({ error: "有効なURLリストが提供されていません" })
  end

  # URLの重複や空文字を整理
  urls = urls.map(&:strip).reject(&:empty?).uniq

  # 非同期で処理を実行 (Threadを使用し、APIレスポンスは即座に返す)
  Thread.new do
    # ActiveRecordのコネクションプールをスレッドごとに確保
    ActiveRecord::Base.connection_pool.with_connection do
      scraper = YodobashiScraper.new
      begin
        urls.each do |url|
          # すでに登録済みかチェック (URLで判定)
          next if Product.exists?(url: url)

          data = scraper.scrape(url)
          if data
            # 10%OFFの目標価格を計算 (1の位切り捨て)
            default_target = 0
            if data[:effective_price] && data[:effective_price] > 0
              calculated = data[:effective_price] * 0.9
              default_target = (calculated / 10).floor * 10
            end

            product = Product.create!(
              name: data[:name],
              url: url,
              target_price: default_target
            )
            # 初期価格履歴を作成 (ここでは新規登録なので通知は飛ばさないが、DBに保存する)
            product.price_histories.create!(
              price: data[:price],
              point_rate: data[:point_rate],
              effective_price: data[:effective_price],
              stock_status: data[:stock_status],
              has_successor: data[:has_successor],
              successor_info: data[:successor_info]
            )
          end
          
          # 連続アクセスによるボット検知を防ぐためのウェイト
          sleep(3)
        end
      rescue => e
        puts "Bulk import error: #{e.message}"
      ensure
        scraper.close
      end
    end
  end

  status 202 # Accepted (処理を受け付けたが完了はしていない)
  json({ message: "#{urls.length}件のURLを受理しました。バックグラウンドで順次登録を行います。" })
end

# 目標価格の10%OFF一括更新API
post '/api/products/bulk_update_targets' do
  content_type :json
  products = Product.all
  updated_count = 0

  products.each do |p|
    latest = p.price_histories.order(created_at: :desc).first
    if latest && latest.effective_price && latest.effective_price > 0
      calculated = latest.effective_price * 0.9
      new_target = (calculated / 10).floor * 10
      p.update!(target_price: new_target)
      updated_count += 1
    end
  end

  json({ message: "#{updated_count}件の目標価格を10%OFFに更新しました" })
end

# GET /api/settings : 設定一覧を取得
get '/api/settings' do
  webhook = Setting.find_by(key: 'discord_webhook_url')
  json({
    discord_webhook_url: webhook&.value || ''
  })
end

# POST /api/settings : 設定を保存
post '/api/settings' do
  request.body.rewind
  payload = JSON.parse(request.body.read)

  webhook = Setting.find_or_initialize_by(key: 'discord_webhook_url')
  webhook.value = payload['discord_webhook_url'] || ''
  webhook.save!

  json({ message: "設定を保存しました" })
end
