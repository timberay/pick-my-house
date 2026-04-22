require "test_helper"

class ChecklistTest < ActiveSupport::TestCase
  setup { Checklist.reset! }

  # Minitest 6 (bundled with Rails 8) removed Object#stub, so we replace the
  # singleton method temporarily and restore it after the block. This mirrors
  # what stub() used to do for the two yaml_path-override tests below.
  def with_yaml_path(path)
    original = Checklist.singleton_class.instance_method(:yaml_path)
    Checklist.define_singleton_method(:yaml_path) { path }
    yield
  ensure
    Checklist.define_singleton_method(:yaml_path) { original.bind(Checklist).call }
  end

  test "loads exactly 10 domains from YAML" do
    assert_equal 10, Checklist.domains.size
  end

  test "first domain is water with expected items" do
    water = Checklist.domains.first
    assert_equal "water", water.key
    assert_equal "수도/배관", water.label_ko
    assert water.items.any? { |i| i.key == "water_pressure" }
  end

  test "item_keys is unique and includes all items" do
    keys = Checklist.item_keys
    total = Checklist.domains.sum { |d| d.items.size }
    assert_equal total, keys.size
    assert_includes keys, "ceiling_corner"
    assert_includes keys, "elevator"
  end

  # NOTE: spec/plan called for 51 items total, but the verbatim YAML in the
  # plan contains 50 items (water 7 + electric 5 + mold 6 + windows 5 +
  # smell 4 + noise 4 + heating 4 + security 4 + finish 6 + surround 5).
  # The spec comment ("10개 도메인 x 4-7항목 = 총 51개") is an off-by-one in
  # the spec itself. We assert the actual count so the test matches the
  # authoritative YAML; add an item (or trim to 50 in spec copy) later.
  test "total item count is 50" do
    assert_equal 50, Checklist.item_keys.size
  end

  test "item(key) returns the matching item with its domain" do
    item = Checklist.item("water_pressure")
    refute_nil item
    assert_equal "water", item.domain
    assert_match(/수압/, item.label_ko)
  end

  test "raises when YAML is missing" do
    Checklist.reset!
    with_yaml_path(Pathname.new("/nonexistent/checklist.yml")) do
      assert_raises(Checklist::Error) { Checklist.domains }
    end
  end

  test "raises when YAML is malformed (not a hash)" do
    Checklist.reset!
    Tempfile.create([ "checklist", ".yml" ]) do |f|
      f.write("- just\n- a\n- list\n")
      f.flush
      with_yaml_path(Pathname.new(f.path)) do
        assert_raises(Checklist::Error) { Checklist.domains }
      end
    end
  end
end
