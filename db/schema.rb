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

ActiveRecord::Schema[8.0].define(version: 2025_09_21_085607) do
  create_table "game_maps", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "thumbnail_url"
    t.text "map_data"
    t.text "map_height"
    t.text "goal_position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "games", force: :cascade do |t|
    t.integer "first_player_ai_id", null: false
    t.integer "second_player_ai_id", null: false
    t.integer "game_map_id", null: false
    t.integer "status"
    t.integer "winner"
    t.string "battle_url"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["first_player_ai_id"], name: "index_games_on_first_player_ai_id"
    t.index ["game_map_id"], name: "index_games_on_game_map_id"
    t.index ["second_player_ai_id"], name: "index_games_on_second_player_ai_id"
  end

  create_table "player_ais", force: :cascade do |t|
    t.string "name"
    t.text "code"
    t.string "author"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "games", "game_maps"
  add_foreign_key "games", "player_ais", column: "first_player_ai_id"
  add_foreign_key "games", "player_ais", column: "second_player_ai_id"
end
