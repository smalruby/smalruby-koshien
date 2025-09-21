class AddMissingColumnsToEnemies < ActiveRecord::Migration[8.0]
  def change
    add_column :enemies, :previous_position_x, :integer
    add_column :enemies, :previous_position_y, :integer
    # killed column already exists, so don't add it
  end
end
