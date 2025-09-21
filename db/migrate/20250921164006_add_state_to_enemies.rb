class AddStateToEnemies < ActiveRecord::Migration[8.0]
  def change
    add_column :enemies, :state, :integer, default: 0, null: false
    add_column :enemies, :enemy_kill, :integer, default: 0, null: false
    add_column :enemies, :killed, :boolean, default: false, null: false
  end
end
