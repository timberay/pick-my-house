class CreateHouses < ActiveRecord::Migration[8.1]
  def change
    create_table :houses do |t|
      t.string :alias, null: false
      t.string :address
      t.string :agent_contact
      t.date :visited_at
      t.string :owner_session_id, null: false

      t.timestamps
    end

    add_index :houses, :owner_session_id
  end
end
