class AddMyMapToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :my_map, :text
    add_column :players, :map_fov, :text
  end
end
