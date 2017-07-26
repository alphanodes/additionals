# Youtube wiki macros
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
  Youtube macro to include youtube video.

    Syntax:

    {{youtube(<video key> [, width=640, height=360, autoplay=BOOL])}}

    Examples:

    {{youtube(KMU0tzLwhbE)}} show video with default size 640x360
    {{youtube(KMU0tzLwhbE, width=853, height=480)}} show video with user defined size
    {{youtube(KMU0tzLwhbE, autoplay=true)}} autoplay video
  EOHELP

      macro :youtube do |_obj, args|
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
          raise 'The correct usage is {{youtube(<video key>[, width=x, height=y])}}'
        end

        v = args[0]
        src = if autoplay
                '//www.youtube.com/embed/' + v + '?autoplay=1'
              else
                '//www.youtube-nocookie.com/embed/' + v
              end
        content_tag(:iframe, '', width: width, height: height, src: src, frameborder: 0, allowfullscreen: 'true')
      end
    end
  end
end
