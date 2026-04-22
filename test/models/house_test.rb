require "test_helper"

class HouseTest < ActiveSupport::TestCase
  SID_A = "00000000-0000-0000-0000-00000000000a".freeze
  SID_B = "00000000-0000-0000-0000-00000000000b".freeze

  test "requires alias" do
    h = House.new(owner_session_id: SID_A)
    refute h.valid?
    assert_includes h.errors[:alias], "can't be blank"
  end

  test "alias max 50 chars" do
    h = House.new(alias: "x" * 51, owner_session_id: SID_A)
    refute h.valid?
    assert_includes h.errors[:alias], "is too long (maximum is 50 characters)"
  end

  test "requires owner_session_id" do
    h = House.new(alias: "Seoul Flat")
    refute h.valid?
    assert_includes h.errors[:owner_session_id], "can't be blank"
  end

  test ".owned_by returns only houses for that session" do
    mine = House.create!(alias: "Mine", owner_session_id: SID_A)
    _theirs = House.create!(alias: "Theirs", owner_session_id: SID_B)
    assert_equal [ mine ], House.owned_by(SID_A).to_a
  end

  test "destroys inspection_checks on destroy" do
    h = House.create!(alias: "Mine", owner_session_id: SID_A)
    h.inspection_checks.create!(item_key: "water_pressure", severity: :ok)
    assert_difference -> { InspectionCheck.count }, -1 do
      h.destroy!
    end
  end
end
