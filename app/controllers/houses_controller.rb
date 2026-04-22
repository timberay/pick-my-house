class HousesController < ApplicationController
  before_action :find_my_house, only: [ :show ]

  def index
    @houses = House.for_owner(current_owner_id).order(created_at: :desc)
  end

  def new
    @house = House.new
  end

  def create
    @house = House.new(house_params.merge(owner_session_id: current_owner_id))
    if @house.save
      redirect_to house_path(@house), notice: "집이 등록되었어요. 방문 중 평가를 시작해 보세요."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @categories = Category.ordered
    @my_ratings = Rating.where(house: @house, rater_session_id: current_owner_id).index_by(&:category_id)
  end

  private

  def house_params
    params.require(:house).permit(:alias_name, :address, :agent_contact)
  end

  def find_my_house
    @house = House.for_owner(current_owner_id).find_by(id: params[:id])
    raise ActiveRecord::RecordNotFound unless @house
  end
end
