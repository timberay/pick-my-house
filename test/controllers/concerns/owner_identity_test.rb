require "test_helper"

class OwnerIdentityTest < ActionDispatch::IntegrationTest
  test "issues signed owner_session_id cookie on first request" do
    get houses_path
    assert_response :success
    assert cookies[:owner_session_id].present?, "owner_session_id cookie should be set"
  end

  test "keeps same owner_session_id across requests" do
    get houses_path
    first = cookies[:owner_session_id]
    get houses_path
    assert_equal first, cookies[:owner_session_id]
  end
end
