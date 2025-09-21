class CreateGameRounds < ActiveRecord::Migration[8.0]
  def change
    create_table :game_rounds do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :round_number, null: false
      t.integer :status, default: 0
      t.integer :winner
      t.text :item_locations

      t.timestamps
    end

    add_index :game_rounds, [:game_id, :round_number], unique: true
  end
end
