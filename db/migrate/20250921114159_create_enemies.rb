class CreateEnemies < ActiveRecord::Migration[8.0]
  def change
    create_table :enemies do |t|
      t.references :game_round, null: false, foreign_key: true
      t.integer :position_x
      t.integer :position_y
      t.integer :hp
      t.integer :attack_power
      t.integer :state, default: 0, null: false
      t.integer :enemy_kill, default: 0, null: false
      t.boolean :killed, default: false, null: false

      t.timestamps
    end
  end
end
