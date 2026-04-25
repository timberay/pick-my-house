require "application_system_test_case"

class HouseDeletionTest < ApplicationSystemTestCase
  test "delete house from edit screen with confirmation" do
    visit root_path
    click_link "새 집 추가"
    fill_in "집 별칭 *", with: "사라질 집"
    click_button "저장"

    click_link "편집"

    # confirm the turbo_confirm dialog
    page.accept_confirm do
      click_button "이 집 삭제"
    end

    assert_current_path houses_path(locale: I18n.default_locale), ignore_query: true
    assert_no_text "사라질 집"
  end
end
