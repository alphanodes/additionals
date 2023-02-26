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

    def test_smilies
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 0 do
        # this is required, because inline_smileys are activated with controller action
        @formatter::RULES << :inline_smileys

        @to_test['A test with a :) smiley'] = 'A test with a <span class="additionals smiley smiley-smiley" title=":)"></span> smiley'
        @to_test[':) :)'] = '<span class="additionals smiley smiley-smiley" title=":)"></span>' \
                            ' <span class="additionals smiley smiley-smiley" title=":)"></span>'

        assert_html_output @to_test
      end
    end

    def test_emojies
      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1,
                                          disable_emoji_native_support: 1 do
        @formatter::RULES.delete :inline_smileys

        str = 'A test with a :heart: emoji and a :) smiley'
        @to_test[str] = 'A test with a <img title="heavy black heart" class="inline_emojify"' \
                        " src=\"http://localhost:3000/#{Additionals::EMOJI_ASSERT_PATH}/emoji_u2764.png\" /> emoji and a :) smiley"

        assert_html_output @to_test
      end
    end

    def test_smilies_and_emojies
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 1,
                                          disable_emoji_native_support: 1 do
        # this is required, because inline_smileys are activated with controller action
        @formatter::RULES << :inline_smileys

        @to_test[':heart: and :)'] = '<img title="heavy black heart" class="inline_emojify"' \
                                     " src=\"http://localhost:3000/#{Additionals::EMOJI_ASSERT_PATH}/emoji_u2764.png\" />" \
                                     ' and <span class="additionals smiley smiley-smiley" title=":)"></span>'
        @to_test[':) and :heart:'] = '<span class="additionals smiley smiley-smiley" title=":)"></span> and' \
                                     ' <img title="heavy black heart" class="inline_emojify"' \
                                     " src=\"http://localhost:3000/#{Additionals::EMOJI_ASSERT_PATH}/emoji_u2764.png\" />"

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
