# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

module WikiFormatting
  class MarkdownTest < ActionView::TestCase
    include Additionals::TestHelper

    def setup
      skip 'Redcarpet is not installed' unless Object.const_defined? :Redcarpet

      @formatter = Redmine::WikiFormatting::Markdown::Formatter
    end

    def test_smilies
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 0 do
        text = 'A small test :) with an smilie'

        assert_equal '<p>A small test <span class="additionals smiley smiley-smiley" title=":)"></span> with an smilie</p>',
                     @formatter.new(text).to_html.strip
      end
    end

    def test_emojies
      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1,
                                          disable_emoji_native_support: 1 do
        text = 'A test with a :heart: emoji'

        assert_equal '<p>A test with a <img title="heavy black heart" class="inline_emojify"' \
                     " src=\"http://localhost:3000/#{Additionals::EMOJI_ASSERT_PATH}/emoji_u2764.png\" /> emoji</p>",
                     @formatter.new(text).to_html.strip
      end
    end

    def test_smilies_and_emojies
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 1,
                                          disable_emoji_native_support: 1 do
        text = ':heart: and :)'

        assert_equal '<p><img title="heavy black heart" class="inline_emojify"' \
                     " src=\"http://localhost:3000/#{Additionals::EMOJI_ASSERT_PATH}/emoji_u2764.png\" />" \
                     ' and <span class="additionals smiley smiley-smiley" title=":)"></span></p>',
                     @formatter.new(text).to_html.strip

        text = ' :) and :heart:'

        assert_equal '<p><span class="additionals smiley smiley-smiley" title=":)"></span> and' \
                     ' <img title="heavy black heart" class="inline_emojify"' \
                     " src=\"http://localhost:3000/#{Additionals::EMOJI_ASSERT_PATH}/emoji_u2764.png\" /></p>",
                     @formatter.new(text).to_html.strip
      end
    end
  end
end
