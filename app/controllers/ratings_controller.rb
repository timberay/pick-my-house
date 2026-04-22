class RatingsController < ApplicationController
  include RaterIdentity

  before_action :load_owner_house_and_category, only: [ :update ]
  before_action :load_rater_house_and_category, only: [ :rater_update ]

  # PATCH /houses/:house_id/ratings/:id
  def update
    upsert_rating!(rater_id: current_owner_id, rater_name: current_owner_name)
    @context = :owner
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to house_path(@house) }
    end
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  # PATCH /s/:share_token/ratings/:category_id
  def rater_update
    rater_id   = current_rater_id_for(@house.share_token)
    rater_name = current_rater_name_for(@house.share_token)
    raise ActiveRecord::RecordNotFound if rater_id.blank?

    upsert_rating!(rater_id: rater_id, rater_name: rater_name)
    @context = :rater
    respond_to do |format|
      format.turbo_stream { render :update }
      format.html { redirect_to share_rate_path(@house.share_token) }
    end
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  private

  def upsert_rating!(rater_id:, rater_name:)
    @rating = Rating.find_or_initialize_by(
      house: @house, category: @category, rater_session_id: rater_id
    )
    rating_params = params.expect(rating: [ :score, :memo ])
    @rating.rater_name = rater_name
    @rating.score      = rating_params[:score]
    @rating.memo       = rating_params[:memo]
    @rating.save!
  end

  def load_owner_house_and_category
    @house    = House.for_owner(current_owner_id).find_by(id: params[:house_id])
    @category = Category.find_by(id: params[:id])
    raise ActiveRecord::RecordNotFound unless @house && @category
  end

  def load_rater_house_and_category
    @house    = House.find_by(share_token: params[:share_token])
    @category = Category.find_by(id: params[:category_id])
    raise ActiveRecord::RecordNotFound unless @house && @category
  end
end
