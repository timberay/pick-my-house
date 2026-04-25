require "test_helper"

class LocaleRoutingTest < ActionDispatch::IntegrationTest
  test "GET /ko/houses returns 200" do
    get "/ko/houses"
    assert_response :success
    assert_select "html[lang=?]", "ko"
  end

  test "GET /en/houses returns 200" do
    get "/en/houses"
    assert_response :success
    # Phase B5 will add <html lang>; for now just confirm 200.
  end

  test "GET /en/houses sets html lang=en" do
    get "/en/houses"
    assert_select "html[lang=?]", "en"
  end

  test "GET /fr/houses returns 404" do
    get "/fr/houses"
    assert_response :not_found
  end

  test "GET /houses (no prefix) returns 200 via fallback" do
    get "/houses"
    assert_response :success
  end

  test "GET / redirects to /<default locale>/houses when no cookie or header" do
    get "/"
    assert_response :redirect
    assert_match %r{\A/(ko|en)/houses\z}, response.location.sub(/\Ahttps?:\/\/[^\/]+/, "")
  end

  test "GET / with Accept-Language: en redirects to /en/houses" do
    get "/", headers: { "Accept-Language" => "en-US,en;q=0.9" }
    assert_response :redirect
    assert_match %r{/en/houses\z}, response.location
  end

  test "GET / with locale cookie wins over Accept-Language" do
    get "/", headers: { "Accept-Language" => "en-US,en;q=0.9", "Cookie" => "locale=ko" }
    assert_response :redirect
    assert_match %r{/ko/houses\z}, response.location
  end

  test "GET /en/houses sets locale cookie to en" do
    get "/en/houses"
    assert_match(/locale=en/, response.headers["Set-Cookie"].to_s)
  end

  test "GET /en/houses renders English UI text" do
    get "/en/houses"
    assert_response :success
    assert_match "My Houses", response.body
    assert_match "All inspection records are stored on this device.", response.body
  end
end
