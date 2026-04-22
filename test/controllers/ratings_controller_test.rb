require "test_helper"

class RatingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Category.seed!
    get houses_path # establish owner cookie
    @owner_id = signed_owner_id
    @house = House.create!(alias_name: "테스트", owner_session_id: @owner_id)
    @cat   = Category.find_by!(key: "school_access")
  end

  test "owner PATCH creates a rating when none exists" do
    patch house_rating_path(@house, @cat.id),
          params: { rating: { score: 4 } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    rating = Rating.find_by!(house: @house, category: @cat, rater_session_id: @owner_id)
    assert_equal 4, rating.score
    assert_equal "나", rating.rater_name
  end

  test "owner PATCH updates existing rating (upsert)" do
    Rating.create!(house: @house, category: @cat, rater_name: "나",
                   rater_session_id: @owner_id, score: 2)
    patch house_rating_path(@house, @cat.id),
          params: { rating: { score: 5 } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_equal 5, Rating.find_by!(house: @house, category: @cat).score
  end

  test "owner PATCH for someone else's house is 404" do
    other = House.create!(alias_name: "남의", owner_session_id: "another")
    patch house_rating_path(other, @cat.id), params: { rating: { score: 3 } }
    assert_response :not_found
  end

  test "score outside 1..5 responds 422" do
    patch house_rating_path(@house, @cat.id), params: { rating: { score: 9 } }
    assert_response :unprocessable_entity
  end

  private

  def signed_owner_id
    jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
    jar.signed[:owner_session_id]
  end
end
