# Vimeo wiki macros
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
  Vimeo macro to include vimeo video.

    Syntax:

    {{vimeo(<video key> [, width=640, height=360, autoplay=BOOL])}}

    Examples:

    {{vimeo(142849533)}} show video with default size 640x360
    {{vimeo(142849533, width=853, height=480)}} show video with user defined size
    {{vimeo(142849533, autoplay=true)}} autoplay video
  EOHELP

      macro :vimeo do |_obj, args|
        args, options = extract_macro_options(args, :width, :height, :autoplay)

        width = 640
        height = 360
        autoplay = false

        width = options[:width] if options[:width].present?
        height = options[:height] if options[:height].present?
        autoplay = true if !options[:autoplay].nil? &&
                           (options[:autoplay] == 'true' || options[:autoplay] == '1')

        if (options[:width].blank? && options[:height].present?) ||
           (options[:width].present? && options[:height].blank?) ||
           args.empty?
          raise 'The correct usage is {{vimeo(<video key>[, width=x, height=y])}}'
        end

        v = args[0]
        src = if autoplay
                '//player.vimeo.com/video/' + v + '?autoplay=1'
              else
                '//player.vimeo.com/video/' + v
              end
        content_tag(:iframe, '', width: width, height: height, src: src, frameborder: 0, allowfullscreen: 'true')
      end
    end
  end
end
