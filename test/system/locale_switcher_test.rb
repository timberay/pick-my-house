require "application_system_test_case"

class LocaleSwitcherTest < ApplicationSystemTestCase
  test "user switches from Korean to English via the header" do
    visit "/ko/houses"
    assert_text "내 집 목록"
    click_link "English"
    assert_current_path %r{/en/houses}
    assert_text "My Houses"
  end

  test "language preference persists in cookie across visits" do
    visit "/ko/houses"
    click_link "English"
    assert_text "My Houses"

    # Revisit the prefix-less root — should land on English page via cookie.
    visit "/"
    assert_current_path %r{/en/houses}
    assert_text "My Houses"
  end

  test "form validation error appears in active locale" do
    visit "/en/houses/new"
    # Remove the HTML5 required attribute so server-side validation runs.
    page.execute_script(<<~JS)
      document.querySelector('input[name="house[alias]"]').removeAttribute('required')
    JS
    click_button "Save"
    assert_text "Please enter a nickname for the house"
  end
end
