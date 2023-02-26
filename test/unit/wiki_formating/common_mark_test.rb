# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

module WikiFormatting
  class CommonMarkTest < ActiveSupport::TestCase
    include Additionals::TestHelper

    def setup
      @options = {}
    end

    def test_smilies
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 0 do
        input = <<~HTML
          A small test :) with an smiley
        HTML
        expected = <<~HTML
          A small test <span class="additionals smiley smiley-smiley" title=":)"></span> with an smiley
        HTML
        assert_equal expected, smiley_filter(input)
      end
    end

    def test_emojis
      input = <<~HTML
        :heart:
        <pre><code>
        def foo
          :heart:
        end
        </code></pre>
      HTML
      expected = <<~HTML
        <img title="heavy black heart" class="inline_emojify" src="http://localhost:3000/#{Additionals::EMOJI_ASSERT_PATH}/emoji_u2764.png">
        <pre><code>
        def foo
          :heart:
        end
        </code></pre>
      HTML

      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1,
                                          disable_emoji_native_support: 1 do
        assert_equal expected, emoji_filter(input)
      end
    end

    private

    def smiley_filter(html)
      Additionals::WikiFormatting::CommonMark::SmileyFilter.to_html html, @options
    end

    def emoji_filter(html)
      Additionals::WikiFormatting::CommonMark::EmojiFilter.to_html html, @options
    end
  end
end
