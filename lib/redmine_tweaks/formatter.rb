# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

module RedmineTweaks
  module Formatter
    SMILEYS = {
      'smiley'      => ':-?\)',                  # :)
      'smiley2'     => '=-?\)',                  # =)
      'laughing'    => ':-?D',                   # :D
      'laughing2'   => '[=]-?D',                 # =D
      'crying'      => '[=:][\'*]\(',            # :'(
      'sad'         => '[=:]-?\(',               # :(
      'wink'        => ';-?[)D]',                # ;)
      'cheeky'      => '[=:]-?[Ppb]',            # :P
      'shock'       => '[=:]-?[Oo0]',            # :O
      'annoyed'     => '[=:]-?[\\/]',            # :/
      'confuse'     => '[=:]-?S',                # :S
      'straight'    => '[=:]-?[\|\]]',           # :|
      'embarrassed' => '[=:]-?[Xx]',             # :X
      'kiss'        => '[=:]-?\*',               # :*
      'angel'       => '[Oo][=:]-?\)',           # O:)
      'evil'        => '>[=:;]-?[)(]',           # >:)
      'rock'        => 'B-?\)',                  # B)
      'rose'        => '@[)\}][-\\/\',;()>\}]*', # @}->-
      'exclamation' => '[\[(]![\])]',            # (!)
      'question'    => '[\[(]\?[\])]',           # (?)
      'check'       => '[\[(]\\/[\])]',          # (/)
      'success'     => '[\[(]v[\])]',            # (v)
      'failure'     => '[\[(]x[\])]'             # (x)
    }.freeze

    def inline_smileys(text)
      SMILEYS.each do |name, regexp|
        text.gsub!(%r{(\s|^)(!)?(#{regexp})(?=\W|$)}m) do
          leading = $1
          esc = $2
          smiley = $3
          if esc.nil?
            leading + content_tag(:span,
                                  '',
                                  class: "tweaks smiley smiley-#{name}",
                                  title: smiley)
          else
            leading + smiley
          end
        end
      end
    end

    def inline_emojify(text)
      text.gsub!(/:([\w+-]+):/) do |match|
        emoji = Emoji.find_by_alias($1)
        if emoji.present?
          tag(:img,
              src: inline_emojify_image_path(emoji.image_filename),
              title: ":#{$1}:",
              style: 'vertical-align: middle',
              width: '20',
              height: '20')
        else
          match
        end
      end
      text
    end

    def inline_emojify_image_path(image_filename)
      path = Setting.protocol + '://' + Setting.host_name
      # TODO: use relative path, if not for mailer
      # path = '/' + Rails.public_path.relative_path_from Rails.root.join('public')
      "#{path}/images/emoji/" + image_filename
    end
  end
end
