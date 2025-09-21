class AddHpToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :hp, :integer, default: 100, null: false
  end
end
