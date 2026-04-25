require "application_system_test_case"

class InspectionFlowTest < ApplicationSystemTestCase
  test "home -> create house -> rate items -> write memo -> see summary" do
    visit root_path
    assert_text "내 집 목록"
    click_link "새 집 추가"

    fill_in "집 별칭 *", with: "신반포 32평"
    click_button "저장"

    assert_text "신반포 32평"

    # first domain (수도/배관) is open by default — rate "수압 충분"
    within("#check-row-water_pressure") do
      click_button "심각"
    end
    # Turbo Stream replaces the row; wait for aria-pressed state.
    assert_selector "#check-row-water_pressure button[aria-pressed='true']", text: "심각"

    # open memo on same row and save
    within("#check-row-water_pressure") do
      find("summary", text: /메모/).click
      find("input[name='memo']").set("2층, 샤워 수압 약함")
      find("button", text: "저장").click
    end

    # memo persisted: summary label switches from "추가" to "수정"
    assert_selector "#check-row-water_pressure summary", text: "메모 수정"

    click_link "요약 보기"
    assert_text "신반포 32평 요약"
    assert_text "심각"
    assert_text "2층, 샤워 수압 약함"
  end
end
