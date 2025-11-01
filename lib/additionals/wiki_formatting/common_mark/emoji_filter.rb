# frozen_string_literal: true

begin
  require 'html/pipeline' unless defined?(HTML::Pipeline)
rescue LoadError
  # HTML::Pipeline is optional on Redmine master where scrubbers are used instead.
end

module Additionals
  module WikiFormatting
    module CommonMark
      if defined?(HTML::Pipeline::Filter)
        class EmojiFilter < HTML::Pipeline::Filter
          include Additionals::Formatter

          def call
            ignore_ancestor_tags = %w[pre code].to_set
            doc.xpath('descendant-or-self::text()').each do |node|
              content = node.to_html
              next if has_ancestor? node, ignore_ancestor_tags
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
        end
      else
        # TODO: Drop this stub once we no longer support Redmine versions that rely on HTML::Pipeline (pre Redmine 7).
        class EmojiFilter
          def initialize(*)
            raise NotImplementedError, 'HTML::Pipeline::Filter is not available'
          end
        end
      end
    end
  end
end
