require 'ferrum'
browser = Ferrum::Browser.new(
  browser_options: {
    'user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'no-sandbox' => nil,
    'disable-dev-shm-usage' => nil
  },
  headless: true
)
browser.goto('https://www.yodobashi.com/product-detail/100000001009713481/')
sleep 2

# Try to find common stock related elements
puts "Stock elements found:"
['.salesInfo', '.stock', '#js_scl_stockMessage', '.ui-stock', '.btn-cart', '.js_stock_message', '.stockMessage', '#stockMessage'].each do |sel|
  nodes = browser.css(sel)
  if nodes.any?
    puts "Selector: #{sel}"
    nodes.each { |n| puts n.text }
  end
end

puts "\nRaw HTML around purchase area:"
purchase_area = browser.css('.p-productDetail_purchase')
if purchase_area.any?
  puts purchase_area.first.inner_html[0..500]
else
  # just dump all text to grep for stock related strings
  puts browser.body.match(/在庫あり|お取り寄せ|販売終了|予定数/)[0] rescue "Nothing found in body"
end

browser.quit
