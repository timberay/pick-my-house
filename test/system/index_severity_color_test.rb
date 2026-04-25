require "application_system_test_case"

class IndexSeverityColorTest < ApplicationSystemTestCase
  test "house card highlights severe count when greater than zero" do
    visit root_path
    click_link "새 집 추가"
    fill_in "집 별칭 *", with: "색 위계 테스트"
    click_button "저장"

    within("#check-row-water_pressure") do
      click_button "심각"
    end
    assert_selector "#check-row-water_pressure button[aria-pressed='true']", text: "심각"

    visit root_path

    severe_span = find("li", text: "색 위계 테스트").find("span", text: /심각 \d+/)
    assert_match(/text-red-700/, severe_span[:class],
      "severe count should be highlighted red when count > 0, classes: #{severe_span[:class]}")
  end

  test "house card greys out severe count when zero" do
    visit root_path
    click_link "새 집 추가"
    fill_in "집 별칭 *", with: "심각 없음"
    click_button "저장"

    visit root_path

    severe_span = find("li", text: "심각 없음").find("span", text: /심각 0/)
    refute_match(/text-red/, severe_span[:class],
      "severe count should not be red when zero, classes: #{severe_span[:class]}")
  end
end
