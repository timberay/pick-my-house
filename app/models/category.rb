class Category < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :label_ko, presence: true
  validates :order, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:order) }
end
