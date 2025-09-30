class AddPlayersDataToGameMaps < ActiveRecord::Migration[8.0]
  def change
    add_column :game_maps, :players_data, :text
  end
end
