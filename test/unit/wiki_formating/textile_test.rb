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

        @to_test['A test with a :) smiley'] = ['#icon--smiley-smiley', 's18 icon-svg smiley']
        @to_test[':) :)'] = ['#icon--smiley-smiley', 's18 icon-svg smiley']

        assert_html_output @to_test
      end
    end

    def test_emojies
      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1 do
        @formatter::RULES.delete :inline_smileys

        @to_test['A test with a :heart: emoji and a :) smiley'] = 'additionals-emoji'

        assert_html_output @to_test
      end
    end

    def test_smileys_and_emojies
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 1 do
        # this is required, because inline_smileys are activated with controller action
        @formatter::RULES << :inline_smileys

        @to_test[':heart: and :)'] = ['#icon--smiley-smiley', 'additionals-emoji']
        @to_test[':) and :heart:'] = ['#icon--smiley-smiley', 'additionals-emoji']

        assert_html_output @to_test
      end
    end

    private

    def assert_html_output(to_test)
      to_test.each do |text, patterns|
        formated_text = @formatter.new(text).to_html

        Array(patterns).each do |pattern|
          assert_includes formated_text, pattern
        end
      end
    end
  end
end
