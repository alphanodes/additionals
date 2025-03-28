# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

module WikiFormatting
  class CommonMarkTest < ActiveSupport::TestCase
    include Additionals::TestHelper

    def setup
      @options = {}
    end

    def test_smileys
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 0 do
        assert_includes smiley_filter('A small test :) with an smiley'), '#icon--smiley-smiley'
        assert_includes smiley_filter('A small test :) with an smiley'), 's18 icon-svg smiley'
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
        #{emoji_heart_tag}
        <pre><code>
        def foo
          :heart:
        end
        </code></pre>
      HTML

      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1 do
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
