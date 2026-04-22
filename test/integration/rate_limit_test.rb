require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
    Rack::Attack.enabled = true
  end

  teardown do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = Rails.cache
  end

  test "more than 60 POSTs /minute from same IP gets throttled" do
    Category.seed!
    60.times do
      post houses_path, params: { house: { alias_name: "x" } },
           env: { "REMOTE_ADDR" => "1.2.3.4" }
    end
    post houses_path, params: { house: { alias_name: "x" } },
         env: { "REMOTE_ADDR" => "1.2.3.4" }
    assert_equal 429, @response.status
  end
end
