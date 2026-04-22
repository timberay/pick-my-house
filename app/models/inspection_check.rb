class InspectionCheck < ApplicationRecord
  belongs_to :house

  enum :severity, { ok: 0, warn: 1, severe: 2 }

  validates :item_key,
    presence: true,
    inclusion: { in: ->(_) { Checklist.item_keys.to_a } },
    uniqueness: { scope: :house_id }
  validates :severity, presence: true
  validates :memo, length: { maximum: 500 }
end
