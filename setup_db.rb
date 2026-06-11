require 'active_record'
require 'sqlite3'
require 'fileutils'

# DBディレクトリがなければ作成
FileUtils.mkdir_p('db')

# SQLiteデータベースへの接続設定 (JavaのJDBC URLのようなもの)
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/database.sqlite3'
)

# マイグレーション: テーブルが存在しなければ作成する (Javaのフライウェイのような機能)
class CreateTables < ActiveRecord::Migration[7.0]
  def change
    # products (監視対象の商品) テーブル
    unless table_exists?(:products)
      create_table :products do |t|
        t.string :name, null: false
        t.string :url, null: false
        t.integer :target_price, null: false, default: 0
        t.timestamps # created_at と updated_at カラムを自動追加
      end
    end

    # price_histories (価格推移) テーブル
    unless table_exists?(:price_histories)
      create_table :price_histories do |t|
        t.references :product, null: false, foreign_key: true
        t.integer :price, null: false          # 販売価格
        t.integer :point_rate, null: false     # ポイント還元率 (10など)
        t.integer :effective_price, null: false # 実質価格
        t.timestamps
      end
    end
  end
end

# マイグレーションを実行
CreateTables.new.change
puts "Database setup complete."
