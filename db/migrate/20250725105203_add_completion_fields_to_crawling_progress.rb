class AddCompletionFieldsToCrawlingProgress < ActiveRecord::Migration[8.0]
  def change
    add_column :crawling_progresses, :output_files, :text
    add_column :crawling_progresses, :output_file_sizes, :text
    add_column :crawling_progresses, :record_count, :integer
    add_column :crawling_progresses, :is_resumable, :boolean, default: false
    
    add_index :crawling_progresses, :step_number
    add_index :crawling_progresses, :status
  end
end
