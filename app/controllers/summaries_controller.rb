class SummariesController < ApplicationController
  def show
    house = House.owned_by(owner_session_id).find_by(id: params[:house_id])
    return head :not_found unless house

    @house = house
    @summary = HouseSummary.for(house)
  end
end
