# frozen_string_literal: true

module Additionals
  module Formatter
    SMILEYS = { 'smiley' => ':-?\)', # :)
                'smiley2' => '=-?\)', # =)
                'laughing' => ':-?D', # :D
                'laughing2' => '[=]-?D', # =D
                'crying' => '[=:][\'*]\(', # :'(
                'sad' => '[=:]-?\(', # :(
                'wink' => ';-?[)D]', # ;)
                'cheeky' => '[=:]-?[Ppb]', # :P
                'shock' => '[=:]-?[Oo0]', # :O
                'annoyed' => '[=:]-?[\\/]', # :/
                'confuse' => '[=:]-?S', # :S
                'straight' => '[=:]-?[\|\]]', # :|
                'embarrassed' => '[=:]-?[Xx]', # :X
                'kiss' => '[=:]-?\*', # :*
                'angel' => '[Oo][=:]-?\)', # O:)
                'evil' => '>[=:;]-?[)(]', # >:)
                'rock' => 'B-?\)', # B)
                'exclamation' => '[\[(]![\])]', # (!)
                'question' => '[\[(]\?[\])]', # (?)
                'check' => '[\[(]\\/[\])]', # (/)
                'success' => '[\[(]v[\])]', # (v)
                'failure' => '[\[(]x[\])]' }.freeze # (x)

    NON_SMILEY_COLOR = %w[exclamation question check success failure].freeze

    def render_inline_smileys(text)
      return text if text.blank?

      content = text.dup
      inline_smileys content
      content
    end

    def inline_smileys(text)
      SMILEYS.each do |name, regexp|
        text.gsub!(/(\s|^|>|\))(!)?(#{regexp})(?=\W|$|<)/m) do
          leading = Regexp.last_match 1
          esc = Regexp.last_match 2
          smiley = Regexp.last_match 3
          if esc.nil?
            css_class = NON_SMILEY_COLOR.exclude?(name) ? 'smiley' : 'info-smiley'
            svg_code = ActionController::Base.helpers.svg_icon_tag "smiley-#{name}",
                                                                   css_class:,
                                                                   wrapper: :span,
                                                                   wrapper_title: smiley

            leading.to_s + ActionController::Base.helpers.tag.span(svg_code,
                                                                   class: "additionals smiley icon smiley-#{name}",
                                                                   wrapper: :span,
                                                                   wrapper_title: smiley)
          else
            leading.to_s + smiley
          end
        end
      end
    end

    def emoji_tag(emoji, _emoji_code = nil)
      return unless emoji

      data = {
        name: emoji.name,
        unicode_version: emoji.unicode_version
      }
      options = { title: emoji.description, data: }

      ActionController::Base.helpers.content_tag 'additionals-emoji', emoji.codepoints, options
    end

    def with_emoji?(text)
      text.match? emoji_pattern
    end

    def emoji_pattern
      @emoji_pattern ||= TanukiEmoji.index.alpha_code_pattern
    end

    def inline_emojify(text)
      return text unless with_emoji? text

      text.gsub! emoji_pattern do |match|
        emoji_code = Regexp.last_match 1
        emoji = TanukiEmoji.find_by_alpha_code emoji_code # rubocop: disable Rails/DynamicFindBy
        if emoji
          emoji_tag emoji, emoji_code
        else
          match
        end
      end
      text
    end
  end
end
