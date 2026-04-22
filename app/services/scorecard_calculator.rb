class ScorecardCalculator
  AGREEMENT_MAX_DIFF    = 1
  DISAGREEMENT_MIN_DIFF = 2
  LEADING_MIN_MARGIN    = 1.0

  Result = Struct.new(:averages, :agreements, :disagreements, keyword_init: true)

  # Analyze a single house's ratings (for couple report).
  # Input: array of { category_key:, rater_id:, score: }
  def self.analyze(rating_rows)
    by_cat = rating_rows.group_by { |r| r[:category_key] }

    averages = {}
    agreements = []
    disagreements = []

    by_cat.each do |key, rows|
      scores = rows.map { |r| r[:score] }
      next unless rows.map { |r| r[:rater_id] }.uniq.size >= 2

      averages[key] = (scores.sum.to_f / scores.size).round(2)
      diff = (scores.max - scores.min).abs
      if diff <= AGREEMENT_MAX_DIFF
        agreements << key
      elsif diff >= DISAGREEMENT_MIN_DIFF
        disagreements << key
      end
    end

    Result.new(averages: averages, agreements: agreements, disagreements: disagreements)
  end

  # Compare the focus house's category averages against other houses' averages.
  # Returns category keys where focus_house_avg >= other_avg + LEADING_MIN_MARGIN.
  # Input: all_houses_ratings = { house_key => rating_rows }, focus_house_key = which to highlight.
  def self.leading_categories(all_houses_ratings:, focus_house_key:)
    averages_by_house = all_houses_ratings.transform_values { |rows| analyze(rows).averages }
    focus = averages_by_house.fetch(focus_house_key, {})
    others = averages_by_house.except(focus_house_key)

    focus.each_with_object([]) do |(cat_key, focus_avg), leading|
      other_values = others.values.filter_map { |h| h[cat_key] }
      next if other_values.empty?
      other_avg = other_values.sum / other_values.size.to_f
      leading << cat_key if focus_avg >= other_avg + LEADING_MIN_MARGIN
    end
  end
end
