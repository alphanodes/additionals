# frozen_string_literal: true

module Additionals
  module WikiFormatting
    module CommonMark
      class EmojiFilter < HTML::Pipeline::Filter
        IGNORED_ANCESTOR_TAGS = %w[pre code].to_set

        include Additionals::Formatter

        def call
          doc.xpath('descendant-or-self::text()').each do |node|
            content = node.to_html
            next if has_ancestor? node, IGNORED_ANCESTOR_TAGS
            next unless with_emoji?(content) || node.text.match(emoji_unicode_pattern)

            html = emoji_unicode_element_unicode_filter content
            html = emoji_name_element_unicode_filter html

            next if html == content

            node.replace html
          end
          doc
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
            emoji_tag_native emoji
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
      end
    end
  end
end
