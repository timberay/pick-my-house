module Localized
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
  end

  def default_url_options
    { locale: I18n.locale }
  end

  private

  def switch_locale(&action)
    locale = LocaleResolver.call(
      param: params[:locale],
      cookie: cookies[:locale],
      accept_language: request.headers["Accept-Language"]
    )
    if locale.to_s != cookies[:locale]
      cookies[:locale] = { value: locale.to_s, expires: 1.year.from_now }
    end
    I18n.with_locale(locale, &action)
  end
end
