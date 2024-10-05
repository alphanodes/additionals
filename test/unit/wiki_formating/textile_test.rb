# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__
require 'digest/md5'

module WikiFormatting
  class TextileTest < ActionView::TestCase
    include Additionals::TestHelper

    def setup
      @formatter = Redmine::WikiFormatting::Textile::Formatter
      @to_test = {}
    end

    def test_smileys
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 0 do
        # this is required, because inline_smileys are activated with controller action
        @formatter::RULES << :inline_smileys

        @to_test['A test with a :) smiley'] =
          "A test with a #{smiley_test_span svg_test_icon} smiley"
        @to_test[':) :)'] = "#{smiley_test_span svg_test_icon} #{smiley_test_span svg_test_icon}"

        assert_html_output @to_test
      end
    end

    def test_emojies
      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1 do
        @formatter::RULES.delete :inline_smileys

        str = 'A test with a :heart: emoji and a :) smiley'
        @to_test[str] = "A test with a #{emoji_heart_tag} emoji and a :) smiley"

        assert_html_output @to_test
      end
    end

    def test_smileys_and_emojies
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 1 do
        # this is required, because inline_smileys are activated with controller action
        @formatter::RULES << :inline_smileys

        @to_test[':heart: and :)'] = "#{emoji_heart_tag} and #{smiley_test_span svg_test_icon}"
        @to_test[':) and :heart:'] = "#{smiley_test_span svg_test_icon} and #{emoji_heart_tag}"

        assert_html_output @to_test
      end
    end

    private

    def assert_html_output(to_test, expect_paragraph: true)
      to_test.each do |text, expected|
        assert_equal(
          (expect_paragraph ? "<p>#{expected}</p>" : expected),
          @formatter.new(text).to_html,
          "Formatting the following text failed:\n===\n#{text}\n===\n"
        )
      end
    end

    def to_html(text)
      @formatter.new(text).to_html
    end
  end
end
