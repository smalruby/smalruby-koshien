class RemoveHpAttributesFromEnemiesAndPlayers < ActiveRecord::Migration[8.0]
  def change
    # Remove hp and attack_power from enemies table (not used in vendor implementation)
    remove_column :enemies, :hp, :integer
    remove_column :enemies, :attack_power, :integer

    # Remove hp from players table (not used in vendor implementation)
    remove_column :players, :hp, :integer
  end
end
