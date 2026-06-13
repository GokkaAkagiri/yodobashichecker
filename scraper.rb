require 'ferrum'
require 'nokogiri'

class YodobashiScraper
  # Ferrumのブラウザインスタンスを保持する
  def initialize
    # Mac上のChromeを利用する設定。ボット対策として一般的なUser-Agentを指定します
    @browser = Ferrum::Browser.new(
      browser_options: {
        'user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'no-sandbox' => nil,
        'disable-dev-shm-usage' => nil
      },
      process_timeout: 60, # 起動タイムアウトを長めに設定
      timeout: 60,         # 読み込みタイムアウト
      headless: true       # 画面を表示せずにバックグラウンドで実行
    )
  end

  # 商品URLを受け取り、価格とポイントのハッシュを返すメソッド
  def scrape(url)
    puts "Scraping URL: #{url}"
    
    # 連続アクセスによるボット検知を防ぐため、ランダムに2〜5秒待機する (Javaの Thread.sleep() に相当)
    sleep(rand(2.0..5.0))
    
    @browser.goto(url)
    
    # DOMが完全に構築されるまで少し待つ（SPA/動的描画への対策）
    sleep(2)
    
    # 描画済みのHTML全体を取得し、Nokogiriで解析(パース)する
    html = @browser.body
    doc = Nokogiri::HTML(html)
    
    # ヨドバシ.comの価格とポイント表示部分をCSSセレクタで抽出
    # ※サイトのHTML構造が変わった場合は、ここを調整する必要があります
    price_text = doc.at_css('#js_scl_unitPrice')&.text
    point_rate_text = doc.at_css('#js_scl_pointRate')&.text || doc.at_css('#js_scl_pointrate')&.text || doc.at_css('.pointRate')&.text || doc.at_css('.point-rate')&.text
    
    # 取れなかった場合のフォールバック（別セレクタを試す）
    if price_text.nil?
      price_text = doc.at_css('.productDetailItem .price')&.text
    end
    
    # 価格が取れない場合でもエラーにせず0とする（販売休止中などで価格が非表示になっているケースの対策）
    price = 0
    if price_text && !price_text.empty?
      price = price_text.gsub(/[^\d]/, '').to_i
    else
      puts "Notice: Could not find price for #{url}, treating as 0"
    end
    
    # 「10％（1,000ポイント）」のような文字列から数値(10)だけを抽出
    # ポイントが見つからなければ0とする
    point_rate = 0
    if point_rate_text
      match = point_rate_text.match(/(\d+)％/)
      point_rate = match[1].to_i if match
    end

    # 実質価格の計算
    point_amount = (price * (point_rate / 100.0)).floor
    effective_price = price - point_amount

    # 商品名の抽出 (h1タグやtitleなどから)
    product_name = doc.at_css('h1')&.text&.strip
    if product_name.nil? || product_name.empty?
      product_name = doc.at_css('title')&.text&.strip&.split(' |')&.first || "名称不明の商品"
    end

    # 在庫状況の抽出
    stock_status = "情報なし"
    
    # 1. カートボタンの存在確認、または「カートに入れる」テキストの存在確認
    body_text_sample = doc.text.gsub(/\s+/, '')
    if doc.at_css('.btn-cart') || body_text_sample.include?("ショッピングカートに入れる")
      stock_status = "在庫あり"
    else
      # 2. テキストによる判定
      buy_box = doc.at_css('#js_buyBoxMain') || doc.at_css('.salesInfo') || doc.at_css('.stock')
      if buy_box
        box_text = buy_box.text.gsub(/\s+/, '')
        if box_text.include?("お取り寄せ")
          stock_status = "お取り寄せ"
        elsif box_text.include?("販売を終了")
          stock_status = "販売終了"
        elsif box_text.include?("販売休止") || box_text.include?("予定数")
          stock_status = "販売休止"
        else
          # 未知の文字列の場合、10文字程度で切り詰めておく（数量1234...などの対策）
          raw_text = buy_box.text.strip.gsub(/\s+/, ' ')
          stock_status = raw_text.length > 10 ? "情報なし" : raw_text
        end
      end
    end

    # 後継機の検知
    has_successor = false
    successor_info = nil
    if doc.text.include?("後継品") || doc.text.include?("後継商品")
      has_successor = true
      # 後継品に関する文言をざっくり抽出
      match = doc.text.match(/(後継品|後継商品)[^。]+。/)
      successor_info = match ? match[0].strip : "後継機あり"
    end

    {
      name: product_name,
      price: price,
      point_rate: point_rate,
      effective_price: effective_price,
      stock_status: stock_status,
      has_successor: has_successor,
      successor_info: successor_info
    }
  rescue => e
    # 例外をキャッチ (Javaの catch(Exception e) に相当)
    puts "Error scraping #{url}: #{e.message}"
    nil
  end

  # 使い終わったブラウザインスタンスを終了させる
  def close
    @browser.quit
  end
end
