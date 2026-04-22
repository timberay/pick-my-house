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
end
