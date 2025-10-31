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

    def test_version_detection_loads_correct_classes
      if Redmine::VERSION::BRANCH == 'devel'
        # Redmine Master should load Scrubbers
        assert defined?(Additionals::WikiFormatting::CommonMark::EmojiScrubber),
               'EmojiScrubber should be defined in Redmine Master'
        assert defined?(Additionals::WikiFormatting::CommonMark::SmileyScrubber),
               'SmileyScrubber should be defined in Redmine Master'
      else
        # Redmine stable should load Filters
        assert defined?(Additionals::WikiFormatting::CommonMark::EmojiFilter),
               'EmojiFilter should be defined in Redmine stable'
        assert defined?(Additionals::WikiFormatting::CommonMark::SmileyFilter),
               'SmileyFilter should be defined in Redmine stable'
      end
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

    def smiley_filter(html)
      if Redmine::VERSION::BRANCH == 'devel'
        fragment = Redmine::WikiFormatting::HtmlParser.parse html
        scrubber = Additionals::WikiFormatting::CommonMark::SmileyScrubber.new
        fragment.scrub! scrubber
        fragment.to_s
      else
        Additionals::WikiFormatting::CommonMark::SmileyFilter.to_html html, @options
      end
    end

    def emoji_filter(html)
      if Redmine::VERSION::BRANCH == 'devel'
        fragment = Redmine::WikiFormatting::HtmlParser.parse html
        scrubber = Additionals::WikiFormatting::CommonMark::EmojiScrubber.new
        fragment.scrub! scrubber
        fragment.to_s
      else
        Additionals::WikiFormatting::CommonMark::EmojiFilter.to_html html, @options
      end
    end
  end
end
