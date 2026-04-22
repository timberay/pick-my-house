require "test_helper"

class SummariesControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_path
    jar = ActionDispatch::Cookies::CookieJar.build(
      ActionDispatch::TestRequest.create, cookies.to_hash
    )
    @sid = jar.signed[:owner_session_id]
    @house = House.create!(alias: "Summary Test", owner_session_id: @sid)
  end

  test "GET summary for empty house shows all unchecked" do
    get house_summary_path(@house)
    assert_response :success
    assert_match "미점검", @response.body
  end

  test "GET summary renders severe and warn sections" do
    @house.inspection_checks.create!(item_key: "rust_free", severity: :severe, memo: "녹물 5초")
    @house.inspection_checks.create!(item_key: "floor_noise", severity: :warn)

    get house_summary_path(@house)
    assert_response :success
    assert_match "녹물 5초", @response.body
    assert_match "심각", @response.body
    assert_match "주의", @response.body
  end

  test "GET summary for other owner returns 404" do
    other = House.create!(alias: "Not yours", owner_session_id: "other-sid")
    get house_summary_path(other)
    assert_response :not_found
  end
end
