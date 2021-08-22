# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class I18nTest < Additionals::TestCase
  include Redmine::I18n

  def setup
    prepare_tests
    User.current = nil
  end

  def teardown
    set_language_if_valid 'en'
  end

  def test_valid_languages
    assert valid_languages.is_a?(Array)
    assert valid_languages.first.is_a?(Symbol)
  end

  def test_locales_validness
    lang_files_count = Dir[Rails.root.join('plugins/additionals/config/locales/*.yml')].size
    assert_equal 13, lang_files_count
    valid_languages.each do |lang|
      assert set_language_if_valid(lang)
      case lang.to_s
      when 'en'
        assert_equal 'Open external URLs', l(:label_open_external_urls)
      when 'pt-BR', 'cs', 'de', 'es', 'fr', 'it', 'ja', 'ko', 'po', 'ru', 'zh-TW', 'zh'
        assert_not l(:label_open_external_urls) == 'Open external URLs', lang
      end
    end

    set_language_if_valid 'en'
  end
end
