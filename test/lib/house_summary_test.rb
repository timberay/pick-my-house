require "test_helper"

class HouseSummaryTest < ActiveSupport::TestCase
  SID = "00000000-0000-0000-0000-000000000222".freeze

  setup do
    Checklist.reset!
    @house = House.create!(alias: "Summary Test", owner_session_id: SID)
  end

  def add_check(item_key, severity, memo: nil)
    @house.inspection_checks.create!(item_key: item_key, severity: severity, memo: memo)
  end

  test "empty house: every item unchecked, zero severe/warn/ok" do
    s = HouseSummary.for(@house)
    assert_equal Checklist.items.size, s.counts[:unchecked]
    assert_equal 0, s.counts[:severe]
    assert_equal 0, s.counts[:warn]
    assert_equal 0, s.counts[:ok]
    assert_empty s.severe_items
    assert_empty s.warn_items
  end

  test "mixed severities: counts and lists populated" do
    add_check("water_pressure", :ok)
    add_check("rust_free", :severe, memo: "녹물 5초")
    add_check("ceiling_corner", :severe)
    add_check("floor_noise", :warn)

    s = HouseSummary.for(@house)
    assert_equal 1, s.counts[:ok]
    assert_equal 1, s.counts[:warn]
    assert_equal 2, s.counts[:severe]
    assert_equal Checklist.items.size - 4, s.counts[:unchecked]

    keys = s.severe_items.map { |entry| entry[:item].key }
    assert_includes keys, "rust_free"
    assert_includes keys, "ceiling_corner"

    rust_entry = s.severe_items.find { |e| e[:item].key == "rust_free" }
    assert_equal "녹물 5초", rust_entry[:check].memo
  end

  test "deleted_items: check whose item_key is no longer in YAML" do
    # simulate by bypassing validation
    check = @house.inspection_checks.build(item_key: "legacy_thing", severity: :warn)
    check.save!(validate: false)

    s = HouseSummary.for(@house)
    assert_equal 1, s.deleted_items.size
    assert_equal "legacy_thing", s.deleted_items.first.item_key
    assert_equal 0, s.counts[:warn], "deleted items must not inflate live counts"
  end

  test "purely functional: works when given checks array, no DB access needed" do
    checks = [
      InspectionCheck.new(item_key: "water_pressure", severity: :ok),
      InspectionCheck.new(item_key: "rust_free", severity: :severe)
    ]
    s = HouseSummary.new(@house, checks)
    assert_equal 1, s.counts[:ok]
    assert_equal 1, s.counts[:severe]
  end
end
