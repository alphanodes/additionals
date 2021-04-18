# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Include iframe

  Syntax:

    {{iframe(<url> [, width=100%, height=485)}}

  Examples:

    show iframe of URL https://www.google.com/
    {{iframe(https://www.google.com/)}}

    show iframe of URL https://www.google.com/ and show link to it
    {{iframe(https://www.google.com/, with_link: true)}}
      DESCRIPTION

      macro :iframe do |_obj, args|
        args, options = extract_macro_options args, :width, :height, :slide, :with_link

        width = options[:width].presence || '100%'
        height = options[:height].presence || 485

        raise 'The correct usage is {{iframe(<url>[, width=x, height=y, with_link=bool])}}' if args.empty?

        src = args[0]
        if Additionals.valid_iframe_url? src
          s = [tag.iframe(width: width,
                          height: height,
                          src: src,
                          frameborder: 0,
                          allowfullscreen: 'true')]
          if !options[:with_link].nil? && Additionals.true?(options[:with_link])
            s << link_to(l(:label_open_in_new_windows), src, class: 'external')
          end
          safe_join s
        elsif Setting.protocol == 'https'
          raise 'Invalid url provided to iframe (only full URLs with protocol HTTPS are accepted)'
        else
          raise 'Invalid url provided to iframe (only full URLs are accepted)'
        end
      end
    end
  end

  def self.valid_iframe_url?(url)
    uri = URI.parse url
    if Setting.protocol == 'https'
      uri.is_a?(URI::HTTPS) && !uri.host.nil?
    else
      !uri.host.nil?
    end
  rescue URI::InvalidURIError
    false
  end
end
