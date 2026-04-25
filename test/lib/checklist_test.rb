require "test_helper"

class ChecklistTest < ActiveSupport::TestCase
  setup { Checklist.reset! }

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
    assert water.items.any? { |i| i.key == "water_pressure" }
  end

  test "item_keys is unique and includes all items" do
    keys = Checklist.item_keys
    total = Checklist.domains.sum { |d| d.items.size }
    assert_equal total, keys.size
    assert_includes keys, "ceiling_corner"
    assert_includes keys, "elevator"
  end

  test "total item count is 50" do
    assert_equal 50, Checklist.item_keys.size
  end

  test "item(key) returns the matching item with its domain" do
    item = Checklist.item("water_pressure")
    refute_nil item
    assert_equal "water", item.domain
    assert_equal "water_pressure", item.key
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
