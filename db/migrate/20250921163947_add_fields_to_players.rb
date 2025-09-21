class AddFieldsToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :bomb_left, :integer, default: 2, null: false
    add_column :players, :walk_bonus_counter, :integer, default: 0, null: false
    add_column :players, :acquired_positive_items, :json, default: [nil, 0, 0, 0, 0, 0]
    # in_water already exists in the schema, so we skip it
  end
end
