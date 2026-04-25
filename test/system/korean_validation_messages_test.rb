require "application_system_test_case"

class KoreanValidationMessagesTest < ApplicationSystemTestCase
  test "submitting the new house form without an alias shows a Korean error message" do
    visit new_house_path
    # Bypass the HTML5 required attribute so the server-side validation runs.
    page.execute_script(<<~JS)
      document.querySelector('input[name="house[alias]"]').removeAttribute('required')
    JS
    click_button "저장"

    error_text = find(".bg-red-50").text
    assert_no_match(/[A-Za-z]/, error_text,
      "validation error should be Korean only, got: #{error_text.inspect}")
    assert_match(/별칭/, error_text,
      "expected the Korean attribute name 별칭 in error, got: #{error_text.inspect}")
  end
end
