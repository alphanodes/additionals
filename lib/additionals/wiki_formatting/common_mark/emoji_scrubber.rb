# frozen_string_literal: true

module Additionals
  module WikiFormatting
    module CommonMark
      # Scrubber version for Redmine Master (7.0+) using Loofah
      class EmojiScrubber < Loofah::Scrubber
        include Additionals::Formatter

        def scrub(node)
          return unless node.text?
          return if ancestor? node, %w[pre code]

          content = node.text
          return unless with_emoji?(content) || content.match(emoji_unicode_pattern)

          html = emoji_unicode_element_unicode_filter content
          html = emoji_name_element_unicode_filter html

          return if html == content

          node.replace html
        end

        # Replace :emoji: with corresponding gl-emoji unicode.
        #
        # text - String text to replace :emoji: in.
        #
        # Returns a String with :emoji: replaced with gl-emoji unicode.
        def emoji_name_element_unicode_filter(text)
          text.gsub emoji_pattern do
            name = Regexp.last_match 1
            emoji = TanukiEmoji.find_by_alpha_code name # rubocop: disable Rails/DynamicFindBy
            emoji_tag emoji, name
          end
        end

        # Replace unicode emoji with corresponding gl-emoji unicode.
        #
        # text - String text to replace unicode emoji in.
        #
        # Returns a String with unicode emoji replaced with gl-emoji unicode.
        def emoji_unicode_element_unicode_filter(text)
          text.gsub emoji_unicode_pattern do |moji|
            emoji = TanukiEmoji.find_by_codepoints moji # rubocop: disable Rails/DynamicFindBy
            emoji_tag emoji
          end
        end

        # Build a regexp that matches all valid unicode emojis names.
        def self.emoji_unicode_pattern
          @emoji_unicode_pattern ||= TanukiEmoji.index.codepoints_pattern
        end

        private

        def emoji_unicode_pattern
          self.class.emoji_unicode_pattern
        end

        # Optimized ancestor check with early exit pattern
        # See Redmine Core Issue #43446 for performance rationale
        def ancestor?(node, tags)
          parent = node.parent
          while parent
            return true if tags.include? parent.name

            parent = parent.parent
          end
          false
        end
      end
    end
  end
end
