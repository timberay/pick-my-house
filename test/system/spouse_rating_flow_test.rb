require "application_system_test_case"

class SpouseRatingFlowTest < ApplicationSystemTestCase
  setup { Category.seed! }

  test "owner rates, spouse rates via share link, data reflects both" do
    # OWNER SIDE — create house + rate 2 categories
    visit root_path
    click_on "새 집 추가"
    fill_in "집 별칭", with: "공유집"
    click_on "이 집 등록하기"

    school_cell = "##{dom_id(Category.find_by!(key: 'school_access'), :rating_cell)}"
    noise_cell  = "##{dom_id(Category.find_by!(key: 'noise'),         :rating_cell)}"

    within(school_cell) { click_on "4" }
    within(noise_cell)  { click_on "2" }

    # Wait for owner's last rating to persist before resetting the session
    within(noise_cell) { find("button.bg-blue-600", text: "2") }

    house = House.last
    share_path = share_session_path(house.share_token)

    # SIMULATE SPOUSE — reset browser session (new cookies), visit share link
    Capybara.current_session.reset!

    visit share_path
    fill_in "rater[name]", with: "남편"
    click_on "평가 시작하기"

    # Spouse is now on /s/:share_token/rate — rate same 2 categories
    within(school_cell) { click_on "5" } # diff 1 → agreement
    within(noise_cell)  { click_on "5" } # diff 3 → disagreement

    # Wait for spouse's last rating to persist before querying the DB
    within(noise_cell) { find("button.bg-blue-600", text: "5") }

    # VERIFY DATA — model-level assertions (more reliable than cross-session UI)
    assert_equal 4, house.ratings.count
    keys = house.ratings.joins(:category).pluck("categories.key").uniq.sort
    assert_equal %w[noise school_access], keys

    # Verify rater names
    rater_names = house.ratings.pluck(:rater_name).uniq.sort
    assert_equal [ "나", "남편" ].sort, rater_names
  end

  test "compare report shows at least one leading category when two houses exist" do
    # Create first house + rate layout low
    visit root_path
    click_on "새 집 추가"
    fill_in "집 별칭", with: "집A"
    click_on "이 집 등록하기"

    layout_cell = "##{dom_id(Category.find_by!(key: 'layout'), :rating_cell)}"
    within(layout_cell) { click_on "3" }

    # Back to index, create second house + rate layout high
    visit root_path
    click_on "새 집 추가"
    fill_in "집 별칭", with: "집B"
    click_on "이 집 등록하기"
    within(layout_cell) { click_on "5" }

    # To have "2 raters" for the leading_categories calc to compute averages,
    # simulate a spouse rating each house via model-level insertion (faster than
    # cross-session UI). This is acceptable because the UI flow was exercised
    # in the previous test.
    house_a = House.find_by!(alias_name: "집A")
    house_b = House.find_by!(alias_name: "집B")
    layout  = Category.find_by!(key: "layout")

    Rating.create!(house: house_a, category: layout, rater_name: "남편",
                   rater_session_id: "spouse-a", score: 3)
    Rating.create!(house: house_b, category: layout, rater_name: "남편",
                   rater_session_id: "spouse-b", score: 5)

    # Visit compare report
    visit compare_houses_path
    assert_text "집 비교 리포트"
    assert_text "집B"
    assert_text "평면 구조"
  end
end
