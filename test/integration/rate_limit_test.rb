require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  setup do
    # Rails.cache is :null_store in test env, which would make Rack::Attack
    # counters useless. Use an in-memory store for this test only.
    @previous_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
    Rack::Attack.enabled = true
  end

  teardown do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = @previous_store
  end

  test "throttles POST /houses after burst" do
    get root_path # mint cookie
    burst = 11
    burst.times do |i|
      post houses_path, params: { house: { alias: "Spam #{i}" } }
    end
    assert_equal 429, response.status, "last of #{burst} POSTs should be throttled"
  end
end
