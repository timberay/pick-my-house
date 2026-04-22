class CreateHouses < ActiveRecord::Migration[8.1]
  def change
    create_table :houses do |t|
      t.string :alias_name,       null: false
      t.string :owner_session_id, null: false
      t.string :share_token,      null: false
      t.string :address
      t.string :agent_contact
      t.timestamps
    end
    add_index :houses, :share_token, unique: true
    add_index :houses, :owner_session_id
  end
end
