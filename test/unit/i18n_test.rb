# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class I18nTest < Additionals::TestCase
  include Redmine::I18n

  def setup
    prepare_tests
  end

  def test_valid_languages
    assert_kind_of Array, valid_languages
    assert_kind_of Symbol, valid_languages.first
  end

  def test_locales_validness
    assert_locales_validness plugin: 'additionals',
                             file_cnt: 14,
                             locales: %w[pt-BR cs de es fr it ja ko po ru uk zh-TW zh],
                             control_string: :label_open_external_urls,
                             control_english: 'Open external URLs'
  end
end
