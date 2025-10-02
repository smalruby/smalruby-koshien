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

ActiveRecord::Schema[8.0].define(version: 2025_10_02_144911) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "enemies", force: :cascade do |t|
    t.integer "game_round_id", null: false
    t.integer "position_x"
    t.integer "position_y"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "state", default: 0, null: false
    t.integer "enemy_kill", default: 0, null: false
    t.boolean "killed", default: false, null: false
    t.integer "previous_position_x"
    t.integer "previous_position_y"
    t.index ["game_round_id"], name: "index_enemies_on_game_round_id"
  end

  create_table "game_events", force: :cascade do |t|
    t.integer "game_turn_id", null: false
    t.string "event_type"
    t.text "event_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "player_id"
    t.datetime "occurred_at"
    t.index ["game_turn_id"], name: "index_game_events_on_game_turn_id"
    t.index ["player_id"], name: "index_game_events_on_player_id"
  end

  create_table "game_maps", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.text "map_data"
    t.text "map_height"
    t.text "goal_position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "players_data"
    t.text "items_data"
  end

  create_table "game_rounds", force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "round_number", null: false
    t.integer "status", default: 0
    t.integer "winner"
    t.text "item_locations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "round_number"], name: "index_game_rounds_on_game_id_and_round_number", unique: true
    t.index ["game_id"], name: "index_game_rounds_on_game_id"
  end

  create_table "game_turns", force: :cascade do |t|
    t.integer "game_round_id", null: false
    t.integer "turn_number"
    t.boolean "turn_finished"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_round_id"], name: "index_game_turns_on_game_round_id"
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

  create_table "player_snapshots", force: :cascade do |t|
    t.integer "game_turn_id", null: false
    t.integer "player_id", null: false
    t.integer "position_x"
    t.integer "position_y"
    t.integer "previous_position_x"
    t.integer "previous_position_y"
    t.integer "score"
    t.integer "status"
    t.boolean "has_goal_bonus"
    t.boolean "in_water"
    t.boolean "movable"
    t.integer "dynamite_left"
    t.integer "character_level"
    t.boolean "walk_bonus"
    t.integer "bomb_left"
    t.integer "walk_bonus_counter"
    t.json "acquired_positive_items"
    t.text "my_map"
    t.text "map_fov"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_turn_id", "player_id"], name: "index_player_snapshots_on_game_turn_id_and_player_id", unique: true
    t.index ["game_turn_id"], name: "index_player_snapshots_on_game_turn_id"
    t.index ["player_id"], name: "index_player_snapshots_on_player_id"
  end

  create_table "players", force: :cascade do |t|
    t.integer "game_round_id", null: false
    t.integer "player_ai_id", null: false
    t.integer "position_x"
    t.integer "position_y"
    t.integer "previous_position_x"
    t.integer "previous_position_y"
    t.integer "score"
    t.integer "status"
    t.boolean "has_goal_bonus"
    t.boolean "in_water"
    t.boolean "movable"
    t.integer "dynamite_left"
    t.integer "character_level"
    t.boolean "walk_bonus"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "bomb_left", default: 2, null: false
    t.integer "walk_bonus_counter", default: 0, null: false
    t.json "acquired_positive_items", default: [nil, 0, 0, 0, 0, 0]
    t.text "my_map"
    t.text "map_fov"
    t.index ["game_round_id"], name: "index_players_on_game_round_id"
    t.index ["player_ai_id"], name: "index_players_on_player_ai_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "enemies", "game_rounds"
  add_foreign_key "game_events", "game_turns"
  add_foreign_key "game_events", "players"
  add_foreign_key "game_rounds", "games"
  add_foreign_key "game_turns", "game_rounds"
  add_foreign_key "games", "game_maps"
  add_foreign_key "games", "player_ais", column: "first_player_ai_id"
  add_foreign_key "games", "player_ais", column: "second_player_ai_id"
  add_foreign_key "player_snapshots", "game_turns"
  add_foreign_key "player_snapshots", "players"
  add_foreign_key "players", "game_rounds"
  add_foreign_key "players", "player_ais"
end
