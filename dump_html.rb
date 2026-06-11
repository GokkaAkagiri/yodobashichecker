require_relative 'scraper'
require 'ferrum'

browser = Ferrum::Browser.new(
  browser_options: {
    'user-agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'no-sandbox' => nil,
    'disable-dev-shm-usage' => nil,
    'window-size' => '1920,1080'
  },
  headless: true
)

begin
  browser.goto("https://www.yodobashi.com/product-detail/100000001009713481/")
  sleep 3 # Wait for dynamic rendering
  File.write('yodobashi_sample.html', browser.body)
  puts "HTML saved to yodobashi_sample.html"
rescue => e
  puts "Error: #{e.message}"
ensure
  browser.quit
end
