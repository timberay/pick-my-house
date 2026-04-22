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

  test "GET /houses/new renders form" do
    get new_house_path
    assert_response :success
    assert_select "form[action='#{houses_path}']"
    assert_select "input[name='house[alias]']"
  end

  test "POST /houses creates house scoped to current session" do
    get root_path # set cookie
    assert_difference -> { House.count }, 1 do
      post houses_path, params: { house: { alias: "신반포 32평", address: "서초구", visited_at: "2026-04-22" } }
    end
    h = House.last
    assert_equal "신반포 32평", h.alias
    assert h.owner_session_id.present?
    assert_redirected_to house_path(h)
  end

  test "POST /houses rejects blank alias" do
    post houses_path, params: { house: { alias: "" } }
    assert_response :unprocessable_entity
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
