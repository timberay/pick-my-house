require "test_helper"

class RatingTest < ActiveSupport::TestCase
  setup do
    Category.seed!
    @house = House.create!(alias_name: "테스트집", owner_session_id: "owner-1")
    @cat   = Category.find_by!(key: "school_access")
  end

  test "score must be between 1 and 5" do
    r = Rating.new(house: @house, category: @cat, rater_name: "아내",
                   rater_session_id: "owner-1", score: 0)
    assert_not r.valid?
    assert_includes r.errors[:score], "must be in 1..5"

    r.score = 6
    assert_not r.valid?

    r.score = 3
    assert r.valid?
  end

  test "rater_name is required" do
    r = Rating.new(house: @house, category: @cat, rater_session_id: "owner-1", score: 3)
    assert_not r.valid?
    assert_includes r.errors[:rater_name], "can't be blank"
  end

  test "rater_session_id is required" do
    r = Rating.new(house: @house, category: @cat, rater_name: "아내", score: 3)
    assert_not r.valid?
    assert_includes r.errors[:rater_session_id], "can't be blank"
  end

  test "same rater cannot double-rate the same category of the same house" do
    Rating.create!(house: @house, category: @cat, rater_name: "아내",
                   rater_session_id: "owner-1", score: 3)
    dup = Rating.new(house: @house, category: @cat, rater_name: "아내",
                     rater_session_id: "owner-1", score: 4)
    assert_not dup.valid?
    assert_includes dup.errors[:category_id], "has already been taken"
  end

  test "different raters can rate the same category of the same house" do
    Rating.create!(house: @house, category: @cat, rater_name: "아내",
                   rater_session_id: "owner-1", score: 3)
    wife = Rating.new(house: @house, category: @cat, rater_name: "남편",
                      rater_session_id: "spouse-1", score: 5)
    assert wife.valid?
  end
end
