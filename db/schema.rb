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

ActiveRecord::Schema[8.1].define(version: 2026_04_22_063702) do
  create_table "houses", force: :cascade do |t|
    t.string "address"
    t.string "agent_contact"
    t.string "alias", null: false
    t.datetime "created_at", null: false
    t.string "owner_session_id", null: false
    t.datetime "updated_at", null: false
    t.date "visited_at"
    t.index ["owner_session_id"], name: "index_houses_on_owner_session_id"
  end

  create_table "inspection_checks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "house_id", null: false
    t.string "item_key", null: false
    t.text "memo"
    t.integer "severity", null: false
    t.datetime "updated_at", null: false
    t.index ["house_id", "item_key"], name: "idx_inspection_checks_unique_per_house_item", unique: true
    t.index ["house_id"], name: "index_inspection_checks_on_house_id"
    t.index ["item_key"], name: "index_inspection_checks_on_item_key"
  end

  add_foreign_key "inspection_checks", "houses"
end
