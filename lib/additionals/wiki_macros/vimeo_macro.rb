# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Vimeo macro to include vimeo video.

  Syntax:

    {{vimeo(<video key> [, width=640, height=360, autoplay=BOOL])}}

  Examples:

    {{vimeo(142849533)}} show video with default size 640x360
    {{vimeo(142849533, width=853, height=480)}} show video with user defined size
    {{vimeo(142849533, autoplay=true)}} autoplay video
      DESCRIPTION

      macro :vimeo do |_obj, args|
        args, options = extract_macro_options args, :width, :height, :autoplay

        width = options[:width].presence || 640
        height = options[:height].presence || 360
        autoplay = !options[:autoplay].nil? && Additionals.true?(options[:autoplay])

        raise 'The correct usage is {{vimeo(<video key>[, width=x, height=y])}}' if args.empty?

        v = args[0]
        src = if autoplay
                "//player.vimeo.com/video/#{v}?autoplay=1"
              else
                "//player.vimeo.com/video/#{v}"
              end
        tag.iframe width: width, height: height, src: src, frameborder: 0, allowfullscreen: 'true'
      end
    end
  end
end
