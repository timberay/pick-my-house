require "test_helper"

class HousesControllerTest < ActionDispatch::IntegrationTest
  setup { Category.seed! }

  test "GET /houses shows only houses owned by current session" do
    get houses_path # mints owner cookie
    owner_id = signed_owner_id
    mine = House.create!(alias_name: "내 집", owner_session_id: owner_id)
    House.create!(alias_name: "남의 집", owner_session_id: "someone-else")

    get houses_path
    assert_response :success
    assert_match "내 집", @response.body
    assert_no_match "남의 집", @response.body
  end

  test "POST /houses creates a house scoped to current owner with share_token" do
    get houses_path # mints cookie
    owner_id = signed_owner_id
    assert_difference -> { House.for_owner(owner_id).count }, 1 do
      post houses_path, params: { house: { alias_name: "신반포 32평" } }
    end
    assert_redirected_to house_path(House.last)
    assert_not_nil House.last.share_token
  end

  test "GET /houses/:id renders only for the owner" do
    get houses_path
    owner_id = signed_owner_id
    mine = House.create!(alias_name: "내 집", owner_session_id: owner_id)
    get house_path(mine)
    assert_response :success
    assert_match "내 집", @response.body
  end

  test "GET /houses/:id returns 404 if not owned" do
    others = House.create!(alias_name: "남의", owner_session_id: "another")
    get houses_path # establishes a different owner cookie
    get house_path(others)
    assert_response :not_found
  end

  private

  # Rails integration tests don't expose cookies.signed directly — rebuild the jar.
  def signed_owner_id
    jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
    jar.signed[:owner_session_id]
  end
end
