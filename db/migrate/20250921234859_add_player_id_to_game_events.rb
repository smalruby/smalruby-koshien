class AddPlayerIdToGameEvents < ActiveRecord::Migration[8.0]
  def change
    add_reference :game_events, :player, null: false, foreign_key: true
  end
end
