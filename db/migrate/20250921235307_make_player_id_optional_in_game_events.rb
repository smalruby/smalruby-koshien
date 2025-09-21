class MakePlayerIdOptionalInGameEvents < ActiveRecord::Migration[8.0]
  def change
    change_column_null :game_events, :player_id, true
  end
end
