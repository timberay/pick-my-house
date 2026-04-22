require "test_helper"

class ScorecardCalculatorTest < ActiveSupport::TestCase
  # Input shape: array of { category_key:, rater_id:, score: }
  def ratings(*tuples)
    tuples.map { |k, r, s| { category_key: k, rater_id: r, score: s } }
  end

  test "single-rater data returns empty agreement/disagreement (needs 2 raters)" do
    result = ScorecardCalculator.analyze(ratings(
      [ "school_access", "owner", 4 ],
      [ "layout",        "owner", 3 ]
    ))
    assert_empty result.agreements
    assert_empty result.disagreements
  end

  test "agreement when both raters within 1 point" do
    result = ScorecardCalculator.analyze(ratings(
      [ "school_access", "owner",  4 ],
      [ "school_access", "spouse", 5 ]
    ))
    assert_equal [ "school_access" ], result.agreements
    assert_empty result.disagreements
  end

  test "disagreement when both raters differ by 2 or more" do
    result = ScorecardCalculator.analyze(ratings(
      [ "layout", "owner",  2 ],
      [ "layout", "spouse", 5 ]
    ))
    assert_equal [ "layout" ], result.disagreements
    assert_empty result.agreements
  end

  test "averages only include categories with both raters present" do
    result = ScorecardCalculator.analyze(ratings(
      [ "layout", "owner",  4 ],
      [ "layout", "spouse", 4 ],
      [ "noise",  "owner",  2 ]   # spouse didn't rate noise → skip in averages
    ))
    assert_equal({ "layout" => 4.0 }, result.averages)
  end

  test "boundary: diff exactly 1 is agreement, diff exactly 2 is disagreement" do
    result = ScorecardCalculator.analyze(ratings(
      [ "a", "o", 3 ], [ "a", "s", 4 ],   # diff 1 → agreement
      [ "b", "o", 3 ], [ "b", "s", 5 ],   # diff 2 → disagreement
      [ "c", "o", 3 ], [ "c", "s", 3 ]    # diff 0 → agreement
    ))
    assert_equal %w[a c].sort, result.agreements.sort
    assert_equal %w[b],       result.disagreements
  end

  test "leading_categories compares multiple houses and picks this house's winners" do
    # 3 houses, 2 categories; house A leads on 'layout' by +1.0 over average of others
    all = {
      "A" => ratings([ "layout", "o", 5 ], [ "layout", "s", 5 ],
                     [ "noise",  "o", 3 ], [ "noise",  "s", 3 ]),
      "B" => ratings([ "layout", "o", 3 ], [ "layout", "s", 3 ],
                     [ "noise",  "o", 4 ], [ "noise",  "s", 4 ]),
      "C" => ratings([ "layout", "o", 3 ], [ "layout", "s", 3 ],
                     [ "noise",  "o", 5 ], [ "noise",  "s", 5 ])
    }
    result = ScorecardCalculator.leading_categories(all_houses_ratings: all, focus_house_key: "A")
    assert_equal [ "layout" ], result
  end
end
