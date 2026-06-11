require 'active_record'

class Product < ActiveRecord::Base
  has_many :price_histories

  # 直近の価格履歴を取得するメソッド (Javaでの public PriceHistory getLatestPriceHistory() に相当)
  def latest_price_history
    price_histories.order(created_at: :desc).first
  end
end
