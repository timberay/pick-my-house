module OwnerIdentity
  extend ActiveSupport::Concern

  COOKIE_NAME = :owner_session_id

  included do
    before_action :ensure_owner_session_id
  end

  private

  def owner_session_id
    cookies.signed[COOKIE_NAME]
  end

  def ensure_owner_session_id
    return if cookies.signed[COOKIE_NAME].present?

    cookies.signed.permanent[COOKIE_NAME] = {
      value: SecureRandom.uuid,
      httponly: true,
      same_site: :lax
    }
  end
end
