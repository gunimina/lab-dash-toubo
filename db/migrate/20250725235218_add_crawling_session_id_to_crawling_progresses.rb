class AddCrawlingSessionIdToCrawlingProgresses < ActiveRecord::Migration[8.0]
  def change
    add_reference :crawling_progresses, :crawling_session, null: false, foreign_key: true
  end
end
