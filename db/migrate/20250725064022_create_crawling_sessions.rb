class CreateCrawlingSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :crawling_sessions do |t|
      t.string :status
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end
end
