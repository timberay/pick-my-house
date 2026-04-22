class Category < ApplicationRecord
  SEED = [
    { key: "school_access", label_ko: "학군 접근성",        order: 1 },
    { key: "layout",        label_ko: "평면 구조",          order: 2 },
    { key: "lighting",      label_ko: "채광 / 향",          order: 3 },
    { key: "noise",         label_ko: "소음",              order: 4 },
    { key: "storage",       label_ko: "수납 공간",          order: 5 },
    { key: "parking",       label_ko: "주차",              order: 6 },
    { key: "condition",     label_ko: "노후도 / 수리 상태",  order: 7 },
    { key: "access",        label_ko: "엘리베이터 / 동선",    order: 8 },
    { key: "builtin",       label_ko: "옵션 / 빌트인",      order: 9 },
    { key: "amenities",     label_ko: "주변 편의시설",      order: 10 }
  ].freeze

  validates :key, presence: true, uniqueness: true
  validates :label_ko, presence: true
  validates :order, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:order) }

  def self.seed!
    SEED.each do |attrs|
      record = find_or_initialize_by(key: attrs[:key])
      record.label_ko = attrs[:label_ko]
      record.order    = attrs[:order]
      record.save!
    end
  end
end
