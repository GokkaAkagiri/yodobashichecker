require 'active_record'
require 'sqlite3'
require 'net/http'
require 'uri'
require 'json'
require_relative 'models/product'
require_relative 'models/price_history'
require_relative 'models/setting'
require_relative 'scraper'

# タイムゾーンを日本時間に設定
require 'active_support/core_ext/time/zones'
Time.zone = 'Tokyo'
ActiveRecord.default_timezone = :local

# DiscordのWebhook URL (環境変数から取得、未設定時は空文字)
DISCORD_WEBHOOK_URL = ENV['DISCORD_WEBHOOK_URL'] || ''

# DB接続
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/database.sqlite3'
)

# 通知を送信するメソッド
def send_discord_notification(product, new_data, old_data, reason)
  # DBに設定があればそれを優先、なければ環境変数
  webhook_setting = Setting.find_by(key: 'discord_webhook_url')
  webhook_url = webhook_setting&.value || DISCORD_WEBHOOK_URL

  if webhook_url.empty?
    puts "DISCORD_WEBHOOK_URL is not set. Skipping notification."
    return
  end

  old_price = old_data ? old_data.effective_price : 'なし'
  
  message = {
    content: "📢 **ヨドバシ価格アラート**\n" \
             "【#{product.name}】\n" \
             "理由: #{reason}\n" \
             "現在の実質価格: **#{new_data[:effective_price]}円** (販売価格: #{new_data[:price]}円, ポイント: #{new_data[:point_rate]}%)\n" \
             "前回取得時の価格: #{old_price}円\n" \
             "目標設定価格: #{product.target_price}円\n" \
             "URL: #{product.url}"
  }

  uri = URI.parse(webhook_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
  request.body = message.to_json

  response = http.request(request)
  puts "Sent Discord notification. Response: #{response.code}"
end

def check_and_notify(product, data, is_manual = false)
  latest_history = product.latest_price_history
  initial_history = product.price_histories.order(created_at: :asc).first

  should_notify = false
  notify_reasons = []

  # クールダウンチェック (手動実行の場合は無視)
  if !is_manual && product.last_notified_at && product.last_notified_at > 3.days.ago
    # 3日以内の通知済みなので、特別な理由がない限りスキップしたいが、
    # 在庫復活や大幅な値下がりは通知したい。今回は簡易的にクールダウンを全適用。
    on_cooldown = true
  else
    on_cooldown = false
  end

  if latest_history
    # 1. 在庫補充の検知 (前回在庫なし/情報なし → 今回在庫あり系)
    old_stock = latest_history.stock_status || "情報なし"
    new_stock = data[:stock_status] || "情報なし"
    
    # ざっくりと「在庫あり」や「お取り寄せ」の文言で判定
    if (old_stock.include?("販売終了") || old_stock.include?("情報なし") || old_stock.include?("予定数")) &&
       (new_stock.include?("在庫あり") || new_stock.include?("お取り寄せ"))
      should_notify = true
      notify_reasons << "🟢 **在庫補充！** (#{old_stock} → #{new_stock})"
    end

    # 2. 値上がり警告（過去最高価格を更新した場合）
    # 歴代最高実質価格を取得
    highest_price = product.price_histories.maximum(:effective_price) || 0
    if data[:effective_price] > highest_price && data[:effective_price] > latest_history.effective_price
      # 1%以上の値上がりのみ通知
      if data[:effective_price] >= latest_history.effective_price * 1.01
        should_notify = true
        notify_reasons << "📈 **値上がり警告** (過去最高価格を更新: 今のうちに買った方がいいかも？)"
      end
    end

    # 3. 通常の値下がり（前回より安くなった）
    if data[:effective_price] < latest_history.effective_price
      should_notify = true
      notify_reasons << "📉 価格が前回より下がりました"
    end
  end

  # 4. 目標価格到達
  if product.target_price > 0 && data[:effective_price] > 0 && data[:effective_price] <= product.target_price
    should_notify = true
    notify_reasons << "🎯 目標価格を下回りました！"
  end

  # 5. 50%OFF（今すぐ買えアラート）と10%OFF通知
  if initial_history && initial_history.effective_price > 0 && data[:effective_price] > 0
    if data[:effective_price] <= initial_history.effective_price * 0.5
      should_notify = true
      notify_reasons << "🚨 **【超特大アラート】今すぐ買え！登録時から50%OFF（半額以下）になっています！！**"
    elsif product.target_price == 0 && data[:effective_price] <= initial_history.effective_price * 0.9
      should_notify = true
      notify_reasons << "🏷️ 登録時の価格から **10%OFF** になりました！"
    end
  end

  # 6. 後継機の検知
  if data[:has_successor] && (!latest_history || !latest_history.has_successor)
    should_notify = true
    notify_reasons << "🆕 **後継機（新商品）が発表されています！** (#{data[:successor_info]})"
  end

  if is_manual
    notify_reasons.unshift("手動更新:")
    should_notify = true if notify_reasons.length > 1 # 手動時は変化があれば通知
  end

  if should_notify && !on_cooldown
    send_discord_notification(product, data, latest_history, notify_reasons.join("\n"))
    # 通知日時を更新
    product.update!(last_notified_at: Time.now)
  elsif should_notify && on_cooldown
    puts "Would notify, but product #{product.name} is on cooldown."
  end

  # DBに履歴を保存
  product.price_histories.create!(
    price: data[:price],
    point_rate: data[:point_rate],
    effective_price: data[:effective_price],
    stock_status: data[:stock_status],
    has_successor: data[:has_successor],
    successor_info: data[:successor_info]
  )
end

def main
  products = Product.all

  if products.empty?
    puts "No products to monitor. Please add some to the database."
    return
  end

  puts "Starting price check for #{products.count} products..."
  
  scraper = YodobashiScraper.new

  products.each do |product|
    puts "Checking: #{product.name}"
    
    # スクレイピング実行
    data = scraper.scrape(product.url)
    
    unless data
      puts "Failed to scrape #{product.name}. Skipping."
      next
    end

    # 通知と保存ロジックを呼び出し
    check_and_notify(product, data)
  end

  # ブラウザを終了
  scraper.close
  puts "Price check finished."
end

# このスクリプトが直接実行された場合のみmainを呼ぶ (Javaの public static void main の役割)
if __FILE__ == $PROGRAM_NAME
  main
end
