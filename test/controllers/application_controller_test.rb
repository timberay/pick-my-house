require "test_helper"

class PingController < ApplicationController
  def index
    head :ok
  end
end

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.application.routes.draw do
      get "/__ping__" => "ping#index"
      get "up" => "rails/health#show", as: :rails_health_check
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "first request assigns an owner_session_id cookie" do
    get "/__ping__"
    owner_id = signed_cookie(:owner_session_id)
    assert_not_nil owner_id
    assert_match(/\A[0-9a-f-]{36}\z/, owner_id)
  end

  test "second request with existing cookie preserves owner_session_id" do
    get "/__ping__"
    first = signed_cookie(:owner_session_id)
    get "/__ping__"
    second = signed_cookie(:owner_session_id)
    assert_equal first, second
  end

  private

  def signed_cookie(name)
    jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
    jar.signed[name]
  end
end
