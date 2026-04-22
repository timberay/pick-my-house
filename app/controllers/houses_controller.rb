class HousesController < ApplicationController
  def index
    @houses = House.owned_by(owner_session_id).order(created_at: :desc)
  end
end
