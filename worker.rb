require_relative 'main'

# 12時間 = 43200秒
INTERVAL_SECONDS = 12 * 60 * 60

puts "Worker started. Will run scraping every 12 hours."

loop do
  begin
    puts "[#{Time.now}] Starting scheduled scraping run..."
    # main.rb 内の main メソッドを呼び出す
    main()
    puts "[#{Time.now}] Scraping run completed."
  rescue => e
    puts "[#{Time.now}] Error in worker: #{e.message}"
  end
  
  puts "Sleeping for 12 hours..."
  sleep(INTERVAL_SECONDS)
end
