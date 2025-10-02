class CreatePlayerSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :player_snapshots do |t|
      t.references :game_turn, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :position_x
      t.integer :position_y
      t.integer :previous_position_x
      t.integer :previous_position_y
      t.integer :score
      t.integer :status
      t.boolean :has_goal_bonus
      t.boolean :in_water
      t.boolean :movable
      t.integer :dynamite_left
      t.integer :character_level
      t.boolean :walk_bonus
      t.integer :bomb_left
      t.integer :walk_bonus_counter
      t.json :acquired_positive_items
      t.text :my_map
      t.text :map_fov

      t.timestamps
    end

    add_index :player_snapshots, [:game_turn_id, :player_id], unique: true
  end
end
