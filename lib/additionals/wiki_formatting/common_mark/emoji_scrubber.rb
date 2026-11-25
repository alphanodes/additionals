# frozen_string_literal: true

module Additionals
  module WikiFormatting
    module CommonMark
      # Scrubber version for Redmine Master (7.0+) using Loofah
      class EmojiScrubber < Loofah::Scrubber
        include Additionals::Formatter

        def scrub(node)
          return unless node.text?
          # skip links too: a raw URL like .../:v:/... is autolinked and its
          # text node would otherwise turn ":v:" into an emoji
          return if ancestor? node, %w[pre code a]

          content = node.text
          unicode = unicode_emoji? content
          named = with_emoji? content
          return unless unicode || named

          html = unicode ? emoji_unicode_element_unicode_filter(content) : content
          html = emoji_name_element_unicode_filter html if named

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

        class << self
          # Build a regexp that matches all valid unicode emojis names.
          def emoji_unicode_pattern
            @emoji_unicode_pattern ||= TanukiEmoji.index.codepoints_pattern
          end

          # The first non-ASCII character of every emoji, from the same codepoints
          # TanukiEmoji builds emoji_unicode_pattern from. A text without any of
          # them holds no emoji, and this small class is checked far faster than
          # the pattern of all emojis - most text nodes never need the latter.
          def emoji_unicode_hint
            @emoji_unicode_hint ||= begin
              chars = TanukiEmoji.index.all.each_with_object Set.new do |emoji, set|
                [emoji.codepoints, *emoji.codepoints_alternates].each do |codepoints|
                  char = codepoints[/[^[:ascii:]]/]
                  set << char if char
                end
              end
              Regexp.new "[#{chars.map { |char| Regexp.escape char }.join}]"
            end
          end
        end

        private

        def emoji_unicode_pattern
          self.class.emoji_unicode_pattern
        end

        def unicode_emoji?(text)
          text.match?(self.class.emoji_unicode_hint) && text.match?(emoji_unicode_pattern)
        end

        # Optimized ancestor check with early exit pattern
        # See Redmine Core Issue https://www.redmine.org/issues/43446 for performance rationale
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
