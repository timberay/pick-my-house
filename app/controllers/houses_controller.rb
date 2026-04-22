class HousesController < ApplicationController
  before_action :set_house, only: [ :show, :edit, :update, :destroy ]

  def index
    @houses = House.owned_by(owner_session_id).order(created_at: :desc)
  end

  def new
    @house = House.new
  end

  def create
    @house = House.new(house_params.merge(owner_session_id: owner_session_id))
    if @house.save
      redirect_to @house
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
  end

  def destroy
  end

  private

  def set_house
    @house = House.owned_by(owner_session_id).find_by(id: params[:id])
    head :not_found unless @house
  end

  def house_params
    params.expect(house: [ :alias, :address, :agent_contact, :visited_at ])
  end
end
