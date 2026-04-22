require "application_system_test_case"

class HouseOwnerFlowTest < ApplicationSystemTestCase
  setup { Category.seed! }

  test "owner creates a house and rates all 10 categories" do
    visit root_path
    click_on "새 집 추가"
    fill_in "집 별칭", with: "신반포 32평"
    click_on "이 집 등록하기"

    assert_text "신반포 32평"

    # Rate first 3 categories
    within("##{dom_id(Category.find_by!(key: 'school_access'), :rating_cell)}") do
      click_on "4"
    end
    assert_text "4/5"

    within("##{dom_id(Category.find_by!(key: 'layout'), :rating_cell)}") do
      click_on "5"
    end
    assert_text "5/5"

    visit house_report_path(House.last)
    assert_text "두 사람 모두 평가한 범주가 아직 없어요."
  end

  test "touch targets are at least 44x44 pixels" do
    visit root_path
    click_on "새 집 추가"
    fill_in "집 별칭", with: "타겟 테스트"
    click_on "이 집 등록하기"
    # Now the house is owned by current session
    button = first("button[name='rating[score]']")
    height = page.evaluate_script("arguments[0].offsetHeight", button)
    assert height >= 44, "rating button should be >= 44px tall (was #{height})"
  end
end
