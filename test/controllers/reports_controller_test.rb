require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Category.seed!
    get houses_path
    @owner_id = signed_owner_id
    @house = House.create!(alias_name: "공유집", owner_session_id: @owner_id)
    @school = Category.find_by!(key: "school_access")
    @noise  = Category.find_by!(key: "noise")

    Rating.create!(house: @house, category: @school, rater_name: "나",
                   rater_session_id: @owner_id, score: 4)
    Rating.create!(house: @house, category: @school, rater_name: "남편",
                   rater_session_id: "spouse-1", score: 5)
    Rating.create!(house: @house, category: @noise, rater_name: "나",
                   rater_session_id: @owner_id, score: 2)
    Rating.create!(house: @house, category: @noise, rater_name: "남편",
                   rater_session_id: "spouse-1", score: 5) # disagreement
  end

  test "GET /houses/:id/report shows averages + agreements + disagreements" do
    get house_report_path(@house)
    assert_response :success
    assert_match "학군 접근성", @response.body
    assert_match "의견 일치", @response.body
    assert_match "의견 갈림", @response.body
    assert_match "소음", @response.body
  end

  test "non-owner cannot view report (404)" do
    foreign = House.create!(alias_name: "남의집", owner_session_id: "someone-else")
    get house_report_path(foreign)
    assert_response :not_found
  end

  test "GET /houses/compare shows leading categories for each house" do
    # Second house, layout favored
    h2 = House.create!(alias_name: "집B", owner_session_id: @owner_id)
    layout = Category.find_by!(key: "layout")
    Rating.create!(house: h2, category: layout, rater_name: "나",
                   rater_session_id: @owner_id, score: 5)
    Rating.create!(house: h2, category: layout, rater_name: "남편",
                   rater_session_id: "spouse-2", score: 5)
    Rating.create!(house: @house, category: layout, rater_name: "나",
                   rater_session_id: @owner_id, score: 3)
    Rating.create!(house: @house, category: layout, rater_name: "남편",
                   rater_session_id: "spouse-1", score: 3)

    get compare_houses_path
    assert_response :success
    assert_match "집B", @response.body
    assert_match "평면 구조", @response.body
  end

  private

  def signed_owner_id
    jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
    jar.signed[:owner_session_id]
  end
end
