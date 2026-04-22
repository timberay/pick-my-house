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

ActiveRecord::Schema[8.1].define(version: 2026_04_22_012151) do
  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "label_ko", null: false
    t.integer "order", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_categories_on_key", unique: true
  end

  create_table "houses", force: :cascade do |t|
    t.string "address"
    t.string "agent_contact"
    t.string "alias_name", null: false
    t.datetime "created_at", null: false
    t.string "owner_session_id", null: false
    t.string "share_token", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_session_id"], name: "index_houses_on_owner_session_id"
    t.index ["share_token"], name: "index_houses_on_share_token", unique: true
  end
end
