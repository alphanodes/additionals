# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class I18nTest < Additionals::TestCase
  def setup
    prepare_tests
  end

  Additionals.define_i18n_tests self,
                                plugin: 'additionals',
                                control_string: :label_open_external_urls,
                                control_english: 'Open external URLs'
end
