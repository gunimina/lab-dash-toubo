class AddCrawlingTypeToCrawlingSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :crawling_sessions, :crawling_type, :string
  end
end
