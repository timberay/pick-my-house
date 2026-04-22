class House < ApplicationRecord
  has_many :inspection_checks, dependent: :destroy

  validates :alias, presence: true, length: { maximum: 50 }
  validates :owner_session_id, presence: true

  scope :owned_by, ->(sid) { where(owner_session_id: sid) }
end
