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

ActiveRecord::Schema[8.1].define(version: 2025_12_15_231347) do
  create_table "drive_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "driver_name", null: false
    t.integer "duration_minutes"
    t.datetime "ended_at"
    t.boolean "is_night_drive", default: false, null: false
    t.text "notes"
    t.datetime "started_at", null: false
    t.string "supervisor_name"
    t.datetime "updated_at", null: false
    t.index ["ended_at"], name: "index_drive_sessions_on_ended_at"
    t.index ["started_at"], name: "index_drive_sessions_on_started_at"
  end
end
