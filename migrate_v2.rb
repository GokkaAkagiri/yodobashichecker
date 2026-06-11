require 'active_record'
require 'sqlite3'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/database.sqlite3'
)

class AddAdvancedColumns < ActiveRecord::Migration[7.0]
  def change
    # 在庫状況や後継機に関する情報を価格履歴に追加
    unless column_exists?(:price_histories, :stock_status)
      add_column :price_histories, :stock_status, :string
    end
    unless column_exists?(:price_histories, :has_successor)
      add_column :price_histories, :has_successor, :boolean, default: false
    end
    unless column_exists?(:price_histories, :successor_info)
      add_column :price_histories, :successor_info, :string
    end

    # クールダウン期間用のタイムスタンプを商品テーブルに追加
    unless column_exists?(:products, :last_notified_at)
      add_column :products, :last_notified_at, :datetime
    end
  end
end

AddAdvancedColumns.new.change
puts "Advanced Migration complete."
