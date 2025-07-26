class CreateCrawlingProgresses < ActiveRecord::Migration[8.0]
  def change
    create_table :crawling_progresses do |t|
      t.integer :step_number
      t.string :step_name
      t.string :status
      t.integer :current_progress
      t.text :message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
