class Rating < ApplicationRecord
  belongs_to :house
  belongs_to :category

  validates :rater_name,       presence: true
  validates :rater_session_id, presence: true
  validates :score,            presence: true, inclusion: { in: 1..5, message: "must be in 1..5" }
  validates :category_id,      uniqueness: { scope: [ :house_id, :rater_session_id ] }
end
