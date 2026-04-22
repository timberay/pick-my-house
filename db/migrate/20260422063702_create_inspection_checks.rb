class CreateInspectionChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :inspection_checks do |t|
      t.references :house, null: false, foreign_key: true
      t.string :item_key, null: false
      t.integer :severity, null: false
      t.text :memo

      t.timestamps
    end

    add_index :inspection_checks, :item_key
    add_index :inspection_checks, [ :house_id, :item_key ], unique: true, name: "idx_inspection_checks_unique_per_house_item"
  end
end
