require "test_helper"

class HousesControllerTest < ActionDispatch::IntegrationTest
  test "GET / is index and sets owner_session_id cookie for first-time visitor" do
    get root_path
    assert_response :success
    assert cookies[:owner_session_id].present?
  end

  test "index shows only houses owned by this session" do
    # seed houses under a specific session id by hand-baking a signed cookie
    get root_path
    my_sid = signed_cookie(:owner_session_id)
    _mine = House.create!(alias: "My flat", owner_session_id: my_sid)
    _theirs = House.create!(alias: "Someone else", owner_session_id: "other-sid")

    get root_path
    assert_match "My flat", @response.body
    refute_match "Someone else", @response.body
  end

  private

  def signed_cookie(name)
    jar = ActionDispatch::Cookies::CookieJar.build(
      ActionDispatch::TestRequest.create,
      cookies.to_hash
    )
    jar.signed[name]
  end
end
