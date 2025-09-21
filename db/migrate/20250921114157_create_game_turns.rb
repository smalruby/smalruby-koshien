class CreateGameTurns < ActiveRecord::Migration[8.0]
  def change
    create_table :game_turns do |t|
      t.references :game_round, null: false, foreign_key: true
      t.integer :turn_number
      t.boolean :turn_finished

      t.timestamps
    end
  end
end
