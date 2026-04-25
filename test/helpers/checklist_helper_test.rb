require "test_helper"

class ChecklistHelperTest < ActionView::TestCase
  test "domain_label returns translated label for a domain key" do
    domain = Checklist.domains.find { |d| d.key == "water" }
    I18n.with_locale(:ko) do
      assert_equal "수도/배관", domain_label(domain)
    end
  end

  test "item_label returns translated label for an item key" do
    item = Checklist.item("water_pressure")
    I18n.with_locale(:ko) do
      assert_equal "수압 충분 (샤워기 세게 틀어서)", item_label(item)
    end
  end
end
