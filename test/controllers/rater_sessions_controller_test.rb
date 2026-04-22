require "test_helper"

class RaterSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Category.seed!
    @house = House.create!(alias_name: "공유 집", owner_session_id: "owner-xyz")
  end

  test "GET /s/:share_token renders name form if no rater cookie" do
    get share_session_path(@house.share_token)
    assert_response :success
    assert_match "이름을 입력", @response.body
  end

  test "invalid share_token returns 404" do
    get share_session_path("not-a-real-token")
    assert_response :not_found
  end

  test "POST /s/:share_token sets rater cookie and redirects to /rate" do
    post share_session_path(@house.share_token), params: { rater: { name: "남편" } }
    assert_redirected_to share_rate_path(@house.share_token)
    assert_not_nil signed_rater_id(@house.share_token)
    assert_equal "남편", signed_rater_name(@house.share_token)
  end

  test "GET /s/:share_token with existing cookie skips form and goes to /rate" do
    post share_session_path(@house.share_token), params: { rater: { name: "남편" } }
    get share_session_path(@house.share_token)
    assert_redirected_to share_rate_path(@house.share_token)
  end

  test "GET /s/:share_token/rate renders categories" do
    post share_session_path(@house.share_token), params: { rater: { name: "남편" } }
    get share_rate_path(@house.share_token)
    assert_response :success
    assert_match "학군 접근성", @response.body
  end

  test "GET /s/:share_token/rate without cookie redirects to name form" do
    get share_rate_path(@house.share_token)
    assert_redirected_to share_session_path(@house.share_token)
  end

  private

  def signed_rater_id(share_token)
    jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
    jar.signed["rater_session_#{share_token}".to_sym]
  end

  def signed_rater_name(share_token)
    jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
    jar.signed["rater_name_#{share_token}".to_sym]
  end
end
