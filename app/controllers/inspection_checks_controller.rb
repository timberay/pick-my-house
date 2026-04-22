class InspectionChecksController < ApplicationController
  before_action :set_house
  before_action :set_check

  VALID_SEVERITIES = %w[ok warn severe].freeze

  def create
    severity = params[:severity].to_s
    return head :unprocessable_entity unless VALID_SEVERITIES.include?(severity)

    @check.severity = severity
    @check.memo = params[:memo] if params.key?(:memo)

    if @check.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @house }
      end
    else
      head :unprocessable_entity
    end
  end

  private

  def set_house
    @house = House.owned_by(owner_session_id).find_by(id: params[:house_id])
    return if @house

    head :not_found
  end

  def set_check
    return unless @house

    @check = @house.inspection_checks.find_or_initialize_by(item_key: params[:item_key])
  end
end
