require "test_helper"

class InspectionChecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    get houses_path
    @sid = cookies[:owner_session_id]
    # Re-resolve signed value through a helper jar
    jar = ActionDispatch::Cookies::CookieJar.build(
      ActionDispatch::TestRequest.create, cookies.to_hash
    )
    @house = House.create!(alias: "Under test", owner_session_id: jar.signed[:owner_session_id])
  end

  test "POST /houses/:id/checks upserts severity (create path)" do
    assert_difference -> { InspectionCheck.count }, 1 do
      post house_checks_path(@house),
           params: { item_key: "water_pressure", severity: "warn" },
           as: :turbo_stream
    end
    assert_response :success
    check = InspectionCheck.last
    assert_equal "warn", check.severity
    assert_equal "water_pressure", check.item_key
  end

  test "Turbo Stream response replaces both the row and the domain progress" do
    post house_checks_path(@house),
         params: { item_key: "water_pressure", severity: "severe" },
         as: :turbo_stream
    assert_response :success
    body = response.body
    assert_match(/<turbo-stream[^>]+action="replace"[^>]+target="check-row-water_pressure"/, body)
    assert_match(/<turbo-stream[^>]+action="replace"[^>]+target="domain-progress-water"/, body)
    assert_match(/진행 1\/7/, body)
  end

  test "POST /houses/:id/checks upserts severity (update path, same item_key)" do
    @house.inspection_checks.create!(item_key: "rust_free", severity: :ok)
    assert_no_difference -> { InspectionCheck.count } do
      post house_checks_path(@house),
           params: { item_key: "rust_free", severity: "severe" },
           as: :turbo_stream
    end
    assert_response :success
    assert_equal "severe", @house.inspection_checks.find_by(item_key: "rust_free").severity
  end

  test "POST includes memo when provided" do
    post house_checks_path(@house),
         params: { item_key: "ceiling_corner", severity: "severe", memo: "북측 천장" },
         as: :turbo_stream
    assert_response :success
    assert_equal "북측 천장", InspectionCheck.last.memo
  end

  test "rejects invalid severity with 422" do
    post house_checks_path(@house),
         params: { item_key: "water_pressure", severity: "panic" },
         as: :turbo_stream
    assert_response :unprocessable_entity
  end

  test "rejects unknown item_key with 422" do
    post house_checks_path(@house),
         params: { item_key: "nope", severity: "ok" },
         as: :turbo_stream
    assert_response :unprocessable_entity
  end

  test "returns 404 when posting to another owner's house" do
    other = House.create!(alias: "Mine not", owner_session_id: "other-sid")
    post house_checks_path(other),
         params: { item_key: "water_pressure", severity: "ok" },
         as: :turbo_stream
    assert_response :not_found
  end
end
