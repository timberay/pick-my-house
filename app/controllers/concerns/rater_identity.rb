module RaterIdentity
  extend ActiveSupport::Concern

  private

  def rater_cookie_key(share_token)
    "rater_session_#{share_token}".to_sym
  end

  def rater_name_cookie_key(share_token)
    "rater_name_#{share_token}".to_sym
  end

  def current_rater_id_for(share_token)
    cookies.signed[rater_cookie_key(share_token)]
  end

  def current_rater_name_for(share_token)
    cookies.signed[rater_name_cookie_key(share_token)]
  end

  def assign_rater_session!(share_token:, name:)
    rater_id = SecureRandom.uuid
    cookies.signed.permanent[rater_cookie_key(share_token)] = {
      value: rater_id, httponly: true, same_site: :lax
    }
    cookies.signed.permanent[rater_name_cookie_key(share_token)] = {
      value: name, httponly: true, same_site: :lax
    }
    rater_id
  end
end
