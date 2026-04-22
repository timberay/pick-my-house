require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActionView::RecordIdentifier # enables dom_id(record, prefix) in system tests

  driven_by :selenium, using: :headless_chrome, screen_size: [ 375, 667 ]
end
