class AddJobIdToCrawlingSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :crawling_sessions, :job_id, :string
  end
end
