require "test_helper"

class HouseTest < ActiveSupport::TestCase
  SESSION_UUID = "11111111-2222-3333-4444-555555555555"

  test "alias is required" do
    h = House.new(owner_session_id: SESSION_UUID)
    assert_not h.valid?
    assert_includes h.errors[:alias_name], "can't be blank"
  end

  test "owner_session_id is required" do
    h = House.new(alias_name: "신반포 32평")
    assert_not h.valid?
    assert_includes h.errors[:owner_session_id], "can't be blank"
  end

  test "share_token is auto-generated on create when blank" do
    h = House.create!(alias_name: "테스트", owner_session_id: SESSION_UUID)
    assert_not_nil h.share_token
    assert_equal 32, h.share_token.length
  end

  test "share_token is unique" do
    House.create!(alias_name: "A", owner_session_id: SESSION_UUID, share_token: "tokenA" + "x" * 26)
    dup = House.new(alias_name: "B", owner_session_id: SESSION_UUID, share_token: "tokenA" + "x" * 26)
    assert_not dup.valid?
    assert_includes dup.errors[:share_token], "has already been taken"
  end

  test "regenerate_share_token! replaces the token" do
    h = House.create!(alias_name: "X", owner_session_id: SESSION_UUID)
    old = h.share_token
    h.regenerate_share_token!
    assert_not_equal old, h.share_token
    assert_equal 32, h.share_token.length
  end

  test "scope for_owner filters by owner_session_id" do
    h1 = House.create!(alias_name: "A", owner_session_id: SESSION_UUID)
    House.create!(alias_name: "B", owner_session_id: "other-uuid")
    assert_equal [ h1 ], House.for_owner(SESSION_UUID).to_a
  end
end
