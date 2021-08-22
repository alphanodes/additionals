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

    def render_inline_smileys(text)
      return text if text.blank?

      inline_smileys text
      text
    end

    def inline_smileys(text)
      SMILEYS.each do |name, regexp|
        text.gsub!(/(\s|^|>|\))(!)?(#{regexp})(?=\W|$|<)/m) do
          leading = Regexp.last_match 1
          esc = Regexp.last_match 2
          smiley = Regexp.last_match 3
          if esc.nil?
            leading + tag.span(class: "additionals smiley smiley-#{name}",
                               title: smiley)
          else
            leading + smiley
          end
        end
      end
    end

    def inline_emojify(text)
      text.gsub!(/:([\w+-]+):/) do |match|
        emoji_code = Regexp.last_match 1
        emoji = Emoji.find_by_alias emoji_code # rubocop:disable Rails/DynamicFindBy
        if emoji.present?
          tag.img src: inline_emojify_image_path(emoji.image_filename),
                  title: ":#{emoji_code}:",
                  style: 'vertical-align: middle',
                  width: '20',
                  height: '20'
        else
          match
        end
      end
      text
    end

    def inline_emojify_image_path(image_filename)
      path = "#{Setting.protocol}://#{Setting.host_name}"
      # TODO: use relative path, if not for mailer
      # path = '/' + Rails.public_path.relative_path_from Rails.root.join('public')
      "#{path}/images/emoji/" + image_filename
    end
  end
end
