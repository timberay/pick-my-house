require "test_helper"

class InspectionCheckTest < ActiveSupport::TestCase
  SID = "00000000-0000-0000-0000-000000000111".freeze

  setup do
    @house = House.create!(alias: "Test", owner_session_id: SID)
  end

  test "severity is an enum of ok/warn/severe" do
    expected = { "ok" => 0, "warn" => 1, "severe" => 2 }
    assert_equal expected, InspectionCheck.severities
  end

  test "requires item_key present and recognised" do
    c = InspectionCheck.new(house: @house, severity: :ok)
    refute c.valid?
    assert_includes c.errors[:item_key], "필수 항목입니다"

    c.item_key = "nonexistent_item"
    refute c.valid?
    assert_includes c.errors[:item_key], "허용되지 않은 값입니다"
  end

  test "valid with known item_key and severity" do
    c = InspectionCheck.new(house: @house, item_key: "water_pressure", severity: :warn)
    assert c.valid?
  end

  test "unique per (house, item_key)" do
    InspectionCheck.create!(house: @house, item_key: "rust_free", severity: :ok)
    dup = InspectionCheck.new(house: @house, item_key: "rust_free", severity: :severe)
    refute dup.valid?
    assert_includes dup.errors[:item_key], "이미 사용 중입니다"
  end

  test "memo limit 500 chars" do
    c = InspectionCheck.new(house: @house, item_key: "noise:floor_noise", severity: :warn, memo: "x" * 501)
    refute c.valid?
    assert_includes c.errors[:memo], "최대 500자까지 가능합니다"
  end
end
