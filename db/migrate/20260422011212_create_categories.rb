class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :key, null: false
      t.string :label_ko, null: false
      t.integer :order, null: false

      t.timestamps
    end
    add_index :categories, :key, unique: true
  end
end
