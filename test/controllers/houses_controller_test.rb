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

  test "GET /houses/:id shows inspection screen with all 10 domains" do
    get root_path
    sid = signed_cookie(:owner_session_id)
    h = House.create!(alias: "Inspection subject", owner_session_id: sid)

    get house_path(h)
    assert_response :success
    assert_match "Inspection subject", @response.body
    Checklist.domains.each do |d|
      assert_match d.label_ko, @response.body
    end
  end

  test "GET /houses/:id for another owner returns 404" do
    other = House.create!(alias: "Not yours", owner_session_id: "other-sid")
    get root_path # mint cookie for this session
    get house_path(other)
    assert_response :not_found
  end

  test "GET /houses/:id/edit shows form" do
    get root_path
    sid = signed_cookie(:owner_session_id)
    h = House.create!(alias: "Edit me", owner_session_id: sid)

    get edit_house_path(h)
    assert_response :success
    assert_select "form"
  end

  test "PATCH /houses/:id updates attributes" do
    get root_path
    sid = signed_cookie(:owner_session_id)
    h = House.create!(alias: "Old", owner_session_id: sid)

    patch house_path(h), params: { house: { alias: "New" } }
    assert_redirected_to house_path(h)
    assert_equal "New", h.reload.alias
  end

  test "DELETE /houses/:id destroys house and checks" do
    get root_path
    sid = signed_cookie(:owner_session_id)
    h = House.create!(alias: "Doomed", owner_session_id: sid)
    h.inspection_checks.create!(item_key: "water_pressure", severity: :ok)

    assert_difference -> { House.count }, -1 do
      assert_difference -> { InspectionCheck.count }, -1 do
        delete house_path(h)
      end
    end
    assert_redirected_to root_path
  end

  test "DELETE /houses/:id for other owner returns 404" do
    other = House.create!(alias: "Not mine", owner_session_id: "other-sid")
    delete house_path(other)
    assert_response :not_found
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
