require 'active_record'
require_relative 'models/product'

# DB接続
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/database.sqlite3'
)

# 引数のチェック
if ARGV.length < 2
  puts "使い方: ruby add_product.rb <商品名> <ヨドバシのURL> [目標価格]"
  puts "例: ruby add_product.rb 'Nintendo Switch' 'https://www.yodobashi.com/product/100000001006509939/' 30000"
  exit
end

name = ARGV[0]
url = ARGV[1]
target_price = ARGV[2] ? ARGV[2].to_i : 0

# 新しい商品を登録 (Javaの em.persist(new Product(...)) に相当)
product = Product.create!(
  name: name,
  url: url,
  target_price: target_price
)

puts "商品を登録しました！"
puts "ID: #{product.id}"
puts "Name: #{product.name}"
puts "URL: #{product.url}"
puts "Target Price: #{product.target_price}円"
