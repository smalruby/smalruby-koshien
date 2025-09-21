class CreateGameMaps < ActiveRecord::Migration[8.0]
  def change
    create_table :game_maps do |t|
      t.string :name
      t.text :description
      t.text :map_data
      t.text :map_height
      t.text :goal_position

      t.timestamps
    end
  end
end
