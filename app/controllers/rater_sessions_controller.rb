class RaterSessionsController < ApplicationController
  include RaterIdentity

  before_action :load_house_by_share_token

  def show
    if current_rater_id_for(@house.share_token).present?
      redirect_to share_rate_path(@house.share_token) and return
    end
    # Else render the name form
  end

  def create
    name = params.require(:rater).permit(:name)[:name].to_s.strip
    if name.blank?
      flash.now[:alert] = "이름을 입력해 주세요."
      render :show, status: :unprocessable_entity and return
    end

    assign_rater_session!(share_token: @house.share_token, name: name)
    redirect_to share_rate_path(@house.share_token)
  end

  def rate
    @categories = Category.ordered
    @rater_name = current_rater_name_for(@house.share_token)
    @my_ratings = Rating.where(house: @house,
                               rater_session_id: current_rater_id_for(@house.share_token))
                        .index_by(&:category_id)
  end

  private

  def load_house_by_share_token
    @house = House.find_by(share_token: params[:share_token])
    raise ActiveRecord::RecordNotFound unless @house
  end
end
