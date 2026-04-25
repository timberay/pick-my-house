require "application_system_test_case"

class MemoOverflowTest < ApplicationSystemTestCase
  test "expanding a memo does not increase horizontal overflow" do
    visit root_path
    click_link "새 집 추가"
    fill_in "집 별칭 *", with: "메모 오버플로 테스트"
    click_button "저장"

    # Rate the first row so the memo toggle becomes available.
    within("#check-row-water_pressure") do
      click_button "심각"
    end
    assert_selector "#check-row-water_pressure button[aria-pressed='true']", text: "심각"

    # Baseline scrollWidth before opening the memo.
    width_before = page.evaluate_script("document.documentElement.scrollWidth")

    # Open the memo details. The memo input has maxlength=500 which Rails
    # turns into size=500, giving the input a ~4266px intrinsic min-width.
    # Without min-w-0 on a flex-1 input, that pushes the page far wider
    # than the viewport whenever any memo is expanded.
    within("#check-row-water_pressure") do
      find("summary", text: /메모/).click
    end

    width_after = page.evaluate_script("document.documentElement.scrollWidth")

    if width_after > width_before
      offenders = page.evaluate_script(<<~JS)
        [...document.querySelectorAll('*')]
          .filter(el => el.scrollWidth > #{width_before})
          .slice(0, 8)
          .map(el => ({ tag: el.tagName, cls: (el.className || '').toString().slice(0, 80), w: el.scrollWidth, c: el.clientWidth }))
      JS
      flunk "opening memo grew scrollWidth from #{width_before}px to #{width_after}px. offenders: #{offenders.inspect}"
    end

    assert_operator width_after, :<=, width_before
  end
end
