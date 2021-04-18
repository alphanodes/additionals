# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Youtube macro to include youtube video.

  Syntax:

    {{youtube(<video key> [, width=640, height=360, autoplay=BOOL])}}

  Examples:

    {{youtube(KMU0tzLwhbE)}} show video with default size 640x360
    {{youtube(KMU0tzLwhbE, width=853, height=480)}} show video with user defined size
    {{youtube(KMU0tzLwhbE, autoplay=true)}} autoplay video
      DESCRIPTION

      macro :youtube do |_obj, args|
        args, options = extract_macro_options args, :width, :height, :autoplay

        width = options[:width].presence || 640
        height = options[:height].presence || 360
        autoplay = !options[:autoplay].nil? && Additionals.true?(options[:autoplay])

        raise 'The correct usage is {{youtube(<video key>[, width=x, height=y])}}' if args.empty?

        v = args[0]
        src = if autoplay
                "//www.youtube.com/embed/#{v}?autoplay=1"
              else
                "//www.youtube-nocookie.com/embed/#{v}"
              end
        tag.iframe width: width, height: height, src: src, frameborder: 0, allowfullscreen: 'true'
      end
    end
  end
end
