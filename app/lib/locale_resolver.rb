require "http_accept_language/parser"

module LocaleResolver
  module_function

  def call(param:, cookie:, accept_language:)
    from_value(param) ||
      from_value(cookie) ||
      from_accept_language(accept_language) ||
      I18n.default_locale
  end

  def from_value(raw)
    return nil if raw.nil? || raw.to_s.empty?
    sym = raw.to_s.to_sym
    I18n.available_locales.include?(sym) ? sym : nil
  end

  def from_accept_language(header)
    return nil if header.nil? || header.empty?
    parser = HttpAcceptLanguage::Parser.new(header)
    locale_str = parser.compatible_language_from(I18n.available_locales.map(&:to_s))
    locale_str&.to_sym
  end
end
