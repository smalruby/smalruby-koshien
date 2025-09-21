class CreatePlayers < ActiveRecord::Migration[8.0]
  def change
    create_table :players do |t|
      t.references :game_round, null: false, foreign_key: true
      t.references :player_ai, null: false, foreign_key: true
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

      t.timestamps
    end
  end
end
