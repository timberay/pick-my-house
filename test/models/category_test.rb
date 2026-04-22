require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "key is required" do
    c = Category.new(label_ko: "학군 접근성", order: 1)
    assert_not c.valid?
    assert_includes c.errors[:key], "can't be blank"
  end

  test "key is unique" do
    Category.create!(key: "school_access", label_ko: "학군 접근성", order: 1)
    dup = Category.new(key: "school_access", label_ko: "다른 라벨", order: 2)
    assert_not dup.valid?
    assert_includes dup.errors[:key], "has already been taken"
  end

  test "ordered scope returns by order ascending" do
    b = Category.create!(key: "b", label_ko: "B", order: 2)
    a = Category.create!(key: "a", label_ko: "A", order: 1)
    assert_equal [ a, b ], Category.ordered.to_a
  end

  CATEGORY_SEED_EXPECTATIONS = [
    { key: "school_access", label_ko: "학군 접근성", order: 1 },
    { key: "layout",        label_ko: "평면 구조",     order: 2 },
    { key: "lighting",      label_ko: "채광 / 향",     order: 3 },
    { key: "noise",         label_ko: "소음",         order: 4 },
    { key: "storage",       label_ko: "수납 공간",     order: 5 },
    { key: "parking",       label_ko: "주차",         order: 6 },
    { key: "condition",     label_ko: "노후도 / 수리 상태", order: 7 },
    { key: "access",        label_ko: "엘리베이터 / 동선",  order: 8 },
    { key: "builtin",       label_ko: "옵션 / 빌트인",   order: 9 },
    { key: "amenities",     label_ko: "주변 편의시설",   order: 10 }
  ].freeze

  test "seed! creates exactly 10 categories with expected keys" do
    Category.seed!
    assert_equal 10, Category.count
    keys = Category.ordered.pluck(:key)
    assert_equal CATEGORY_SEED_EXPECTATIONS.map { |c| c[:key] }, keys
  end

  test "seed! is idempotent — calling twice still leaves 10 rows" do
    Category.seed!
    Category.seed!
    assert_equal 10, Category.count
  end

  test "seed! updates label_ko if an existing key has a stale label" do
    Category.create!(key: "school_access", label_ko: "old label", order: 1)
    Category.seed!
    assert_equal "학군 접근성", Category.find_by(key: "school_access").label_ko
  end
end
