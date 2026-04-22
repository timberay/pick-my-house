module OwnerIdentity
  extend ActiveSupport::Concern

  OWNER_COOKIE       = :owner_session_id
  OWNER_NAME_COOKIE  = :owner_display_name

  included do
    before_action :assign_owner_session_id
    helper_method :current_owner_id, :current_owner_name
  end

  private

  def current_owner_id
    cookies.signed[OWNER_COOKIE]
  end

  def current_owner_name
    cookies.signed[OWNER_NAME_COOKIE].presence || "나"
  end

  def assign_owner_session_id
    return if cookies.signed[OWNER_COOKIE].present?

    cookies.signed.permanent[OWNER_COOKIE] = {
      value: SecureRandom.uuid,
      httponly: true,
      same_site: :lax
    }
  end
end
