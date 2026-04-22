class ReportsController < ApplicationController
  before_action :load_my_house, only: [ :show ]

  def show
    rows = @house.ratings.includes(:category).map do |r|
      { category_key: r.category.key, rater_id: r.rater_session_id, score: r.score }
    end
    @result = ScorecardCalculator.analyze(rows)
    @categories_by_key = Category.ordered.index_by(&:key)
  end

  def compare
    @houses = House.for_owner(current_owner_id).includes(ratings: :category)
    all_rows = @houses.each_with_object({}) do |h, memo|
      memo[h.alias_name] = h.ratings.map do |r|
        { category_key: r.category.key, rater_id: r.rater_session_id, score: r.score }
      end
    end
    @leaders = @houses.each_with_object({}) do |h, memo|
      memo[h.id] = ScorecardCalculator.leading_categories(
        all_houses_ratings: all_rows, focus_house_key: h.alias_name
      )
    end
    @categories_by_key = Category.ordered.index_by(&:key)
  end

  private

  def load_my_house
    @house = House.for_owner(current_owner_id).find_by(id: params[:house_id])
    raise ActiveRecord::RecordNotFound unless @house
  end
end
