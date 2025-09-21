class CreatePlayerAis < ActiveRecord::Migration[8.0]
  def change
    create_table :player_ais do |t|
      t.string :name
      t.text :code
      t.string :author
      t.datetime :expires_at

      t.timestamps
    end
  end
end
