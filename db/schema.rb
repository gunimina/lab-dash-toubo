# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_26_060334) do
  create_table "crawling_progresses", force: :cascade do |t|
    t.integer "step_number"
    t.string "step_name"
    t.string "status"
    t.integer "current_progress"
    t.text "message"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "output_files"
    t.text "output_file_sizes"
    t.integer "record_count"
    t.boolean "is_resumable", default: false
    t.integer "crawling_session_id", null: false
    t.index ["crawling_session_id"], name: "index_crawling_progresses_on_crawling_session_id"
    t.index ["status"], name: "index_crawling_progresses_on_status"
    t.index ["step_number"], name: "index_crawling_progresses_on_step_number"
  end

  create_table "crawling_sessions", force: :cascade do |t|
    t.string "status"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "crawling_type"
    t.string "job_id"
  end

  add_foreign_key "crawling_progresses", "crawling_sessions"
end
