# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

module WikiFormatting
  class MarkdownTest < ActionView::TestCase
    include Additionals::TestHelper

    def setup
      skip 'Redcarpet is not installed' unless Object.const_defined? :Redcarpet

      @formatter = Redmine::WikiFormatting::Markdown::Formatter
    end

    def test_smileys
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 0 do
        text = 'A small test :) with an smilie'

        assert_equal "<p>A small test #{smiley_test_span svg_test_icon} with an smilie</p>",
                     @formatter.new(text).to_html.strip
      end
    end

    def test_emojies
      with_plugin_settings 'additionals', legacy_smiley_support: 0,
                                          emoji_support: 1 do
        text = 'A test with a :heart: emoji'

        assert_equal "<p>A test with a #{emoji_heart_tag} emoji</p>",
                     @formatter.new(text).to_html.strip
      end
    end

    def test_smileys_and_emojies
      with_plugin_settings 'additionals', legacy_smiley_support: 1,
                                          emoji_support: 1 do
        text = ':heart: and :)'

        assert_equal "<p>#{emoji_heart_tag} and #{smiley_test_span svg_test_icon}</p>",
                     @formatter.new(text).to_html.strip

        text = ' :) and :heart:'

        assert_equal "<p>#{smiley_test_span svg_test_icon} and #{emoji_heart_tag}</p>",
                     @formatter.new(text).to_html.strip
      end
    end
  end
end
