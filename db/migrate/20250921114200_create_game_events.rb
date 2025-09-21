class CreateGameEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :game_events do |t|
      t.references :game_turn, null: false, foreign_key: true
      t.string :event_type
      t.text :event_data

      t.timestamps
    end
  end
end
