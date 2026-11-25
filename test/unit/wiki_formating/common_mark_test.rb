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

    def test_smileys_not_in_code_blocks
      input = '<pre><code>:)</code></pre>'
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 0 do
        result = smiley_filter input

        assert_not_includes result, 'icon--smiley-smiley'
        assert_includes result, ':)'
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

    def test_emojis_not_in_code_blocks
      input = '<pre><code>:heart:</code></pre>'
      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1 do
        result = emoji_filter input

        assert_not_includes result, '<additionals-emoji'
        assert_includes result, ':heart:'
      end
    end

    def test_emojis_not_in_links
      input = '<a href="https://example.com/:heart:/g/x">https://example.com/:heart:/g/x</a>'
      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1 do
        result = emoji_filter input

        assert_not_includes result, '<additionals-emoji'
        assert_includes result, ':heart:'
      end
    end

    def test_unicode_emojis_not_in_links
      input = '<a href="https://example.com/x">https://example.com/✌️/x</a>'
      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1 do
        result = emoji_filter input

        assert_not_includes result, '<additionals-emoji'
      end
    end

    def test_emojis_still_render_next_to_links
      input = ':heart: <a href="https://example.com/">link</a>'
      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1 do
        result = emoji_filter input

        assert_includes result, '<additionals-emoji'
        assert_not_includes result, ':heart:'
      end
    end

    def test_emojis_still_render_outside_code_and_links
      input = ':heart:'
      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1 do
        result = emoji_filter input

        assert_includes result, '<additionals-emoji'
        assert_not_includes result, ':heart:'
      end
    end

    def test_escaped_smiley_stays_text
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 0 do
        result = smiley_filter 'An escaped !:) smiley'

        assert_not_includes result, 'icon--smiley-smiley'
        assert_includes result, ' :) '
      end
    end

    # The emoji scrubber only looks closer at text that can hold an emoji:
    # these cases guard that the shortcut misses none.
    def test_unicode_emojis_next_to_umlauts_digits_and_keycaps
      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1 do
        result = emoji_filter 'Prüfung ❤️ für Version 1.2, Schritt 1️⃣ und ©️'

        assert_equal 3, result.scan('<additionals-emoji').size
      end
    end

    def test_text_without_emoji_stays_unchanged
      input = 'Version 3.1: Änderungen für die Übersicht (siehe #12) - 50 % erledigt'

      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1 do
        assert_equal input, emoji_filter(input)
      end
    end

    # Every indexed emoji contains one of the hint characters, otherwise the
    # shortcut would skip it - fails if a TanukiEmoji update breaks that.
    def test_emoji_unicode_hint_covers_every_indexed_emoji
      hint = Additionals::WikiFormatting::CommonMark::EmojiScrubber.emoji_unicode_hint
      missed = indexed_emoji_codepoints.grep_v hint

      assert_empty missed
    end

    def test_scrubbers_are_defined
      assert defined?(Additionals::WikiFormatting::CommonMark::EmojiScrubber),
             'EmojiScrubber should be defined'
      assert defined?(Additionals::WikiFormatting::CommonMark::SmileyScrubber),
             'SmileyScrubber should be defined'
    end

    def test_formatter_uses_correct_implementation
      text = 'Test with emoji :heart: and smiley :)'

      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 1 do
        formatter = Redmine::WikiFormatting::CommonMark::Formatter.new text
        result = formatter.to_html

        assert_includes result, emoji_heart_tag, 'Should process emoji'
        assert_includes result, '#icon--smiley-smiley', 'Should process smiley'
      end
    end

    private

    def indexed_emoji_codepoints
      TanukiEmoji.index.all.flat_map { |emoji| [emoji.codepoints, *emoji.codepoints_alternates] }
    end

    def smiley_filter(html)
      fragment = Redmine::WikiFormatting::HtmlParser.parse html
      fragment.scrub! Additionals::WikiFormatting::CommonMark::SmileyScrubber.new
      fragment.to_s
    end

    def emoji_filter(html)
      fragment = Redmine::WikiFormatting::HtmlParser.parse html
      fragment.scrub! Additionals::WikiFormatting::CommonMark::EmojiScrubber.new
      fragment.to_s
    end
  end
end
