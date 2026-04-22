class CreateRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :ratings do |t|
      t.references :house,    null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string  :rater_name,       null: false
      t.string  :rater_session_id, null: false
      t.integer :score,            null: false
      t.text    :memo
      t.timestamps
    end
    add_index :ratings, [ :house_id, :category_id, :rater_session_id ],
              unique: true, name: "idx_ratings_unique_per_rater"
  end
end
