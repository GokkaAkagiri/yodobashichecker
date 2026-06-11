require 'open-uri'
require 'nokogiri'

url = 'https://www.yodobashi.com/product-detail/100000001009713481/'
html = URI.open(url, "User-Agent" => "Mozilla/5.0").read
doc = Nokogiri::HTML(html)

puts "Stock related nodes:"
# Search for any element containing "在庫あり" or "お取り寄せ" or "販売終了"
nodes = doc.xpath('//*[contains(text(), "在庫あり") or contains(text(), "お取り寄せ") or contains(text(), "販売休止") or contains(text(), "販売を終了")]')
nodes.each do |n|
  puts "<#{n.name} class='#{n['class']}' id='#{n['id']}'> #{n.text.strip} </#{n.name}>"
end
