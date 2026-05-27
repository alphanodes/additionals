# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class I18nTest < Additionals::TestCase
  def setup
    prepare_tests
  end

  Additionals.define_i18n_tests self,
                                plugin: 'additionals',
                                file_cnt: 14,
                                locales: %w[pt-BR cs de es fr it ja ko po ru uk zh-TW zh],
                                control_string: :label_open_external_urls,
                                control_english: 'Open external URLs'
end
