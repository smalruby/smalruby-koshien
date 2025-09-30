class AddItemsDataToGameMaps < ActiveRecord::Migration[8.0]
  def change
    add_column :game_maps, :items_data, :text
  end
end
