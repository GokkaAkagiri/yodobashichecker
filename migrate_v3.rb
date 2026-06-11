require 'active_record'
require 'sqlite3'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/database.sqlite3'
)

class CreateSettingsTable < ActiveRecord::Migration[7.0]
  def change
    unless table_exists?(:settings)
      create_table :settings do |t|
        t.string :key, null: false
        t.string :value
        t.timestamps
      end
      add_index :settings, :key, unique: true
    end
  end
end

CreateSettingsTable.new.change
puts "Settings table migration complete."

# 初期Webhookデータの挿入
class Setting < ActiveRecord::Base; end
webhook = Setting.find_or_initialize_by(key: 'discord_webhook_url')
if webhook.value.nil? || webhook.value.empty?
  webhook.value = 'https://discord.com/api/webhooks/1504142137632096376/qSCvp1c2BNa732mCIxA7D2O1tJncq8LJim0kXuqmXvtfEIBQub-D84EsVMYgLTQ4A_uP'
  webhook.save!
  puts "Default Webhook URL saved."
end
