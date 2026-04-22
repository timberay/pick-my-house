require "test_helper"

class PwaManifestTest < ActionDispatch::IntegrationTest
  test "manifest.json returns valid JSON with name, icons, start_url" do
    get "/manifest.json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal "Pick My House", json["name"]
    assert_equal "/", json["start_url"]
    assert_equal "standalone", json["display"]
    assert_kind_of Array, json["icons"]
    assert json["icons"].any?
  end
end
