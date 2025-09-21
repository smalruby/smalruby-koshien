class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.references :first_player_ai, null: false, foreign_key: {to_table: :player_ais}
      t.references :second_player_ai, null: false, foreign_key: {to_table: :player_ais}
      t.references :game_map, null: false, foreign_key: true
      t.integer :status
      t.integer :winner
      t.string :battle_url
      t.datetime :completed_at

      t.timestamps
    end
  end
end
