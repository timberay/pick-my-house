require "test_helper"

class LocaleResolverTest < ActiveSupport::TestCase
  test "returns the param locale when valid" do
    assert_equal :en, LocaleResolver.call(param: "en", cookie: nil, accept_language: nil)
    assert_equal :ko, LocaleResolver.call(param: "ko", cookie: nil, accept_language: nil)
  end

  test "ignores invalid param and falls back to cookie" do
    assert_equal :ko, LocaleResolver.call(param: "fr", cookie: "ko", accept_language: nil)
  end

  test "ignores empty string param" do
    assert_equal :ko, LocaleResolver.call(param: "", cookie: "ko", accept_language: nil)
  end

  test "uses cookie when param is nil" do
    assert_equal :en, LocaleResolver.call(param: nil, cookie: "en", accept_language: nil)
  end

  test "ignores invalid cookie value" do
    assert_equal I18n.default_locale,
                 LocaleResolver.call(param: nil, cookie: "'; DROP TABLE users; --", accept_language: nil)
  end

  test "uses Accept-Language when param and cookie are nil" do
    assert_equal :en,
                 LocaleResolver.call(param: nil, cookie: nil, accept_language: "en-US,en;q=0.9,ko;q=0.8")
    assert_equal :ko,
                 LocaleResolver.call(param: nil, cookie: nil, accept_language: "ko,en;q=0.9")
  end

  test "Accept-Language with no compatible language falls back to default" do
    assert_equal I18n.default_locale,
                 LocaleResolver.call(param: nil, cookie: nil, accept_language: "fr-FR,fr;q=0.9")
  end

  test "all inputs nil returns default locale" do
    assert_equal I18n.default_locale,
                 LocaleResolver.call(param: nil, cookie: nil, accept_language: nil)
  end

  test "param wins over cookie wins over accept_language" do
    assert_equal :en,
                 LocaleResolver.call(param: "en", cookie: "ko", accept_language: "ko")
    assert_equal :ko,
                 LocaleResolver.call(param: nil, cookie: "ko", accept_language: "en")
  end

  test "Accept-Language with malformed bytes falls back to default" do
    bad_header = "\xC3\x28invalid".dup.force_encoding("UTF-8")
    assert_equal I18n.default_locale,
                 LocaleResolver.call(param: nil, cookie: nil, accept_language: bad_header)
  end
end
