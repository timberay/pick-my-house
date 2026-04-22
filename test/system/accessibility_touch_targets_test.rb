require "application_system_test_case"

class AccessibilityTouchTargetsTest < ApplicationSystemTestCase
  test "severity buttons meet 44x44 minimum touch target" do
    visit root_path
    click_link "+ 새 집 추가"
    fill_in "집 별칭 *", with: "접근성 테스트"
    click_button "저장"

    # first row of first open domain
    first_row = find("div[id^='check-row-']", match: :first)
    within(first_row) do
      %w[양호 주의 심각].each do |label|
        btn = find("button", text: label)
        rect = btn.evaluate_script("({ w: this.offsetWidth, h: this.offsetHeight })")
        assert_operator rect["w"], :>=, 44, "#{label} button width #{rect['w']}px < 44"
        assert_operator rect["h"], :>=, 44, "#{label} button height #{rect['h']}px < 44"
      end
    end
  end
end
