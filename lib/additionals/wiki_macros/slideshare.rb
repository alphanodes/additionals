# Slideshare wiki macros
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
  Slideshare macro to include Slideshare slide.

    Syntax:

    {{slideshare(<key> [, width=595, height=485, slide=SLIDE])}}

    Examples:

    {{slideshare(57941706)}} show slideshare slid with default size 595x485
    {{slideshare(57941706, width=514, height=422)}} show video with user defined size
    {{slideshare(57941706, slide=5)}} start with slide (page) 5
  EOHELP

      macro :slideshare do |_obj, args|
        args, options = extract_macro_options(args, :width, :height, :slide)

        width = 595
        height = 485
        slide = 0

        width = options[:width] if options[:width].present?
        height = options[:height] if options[:height].present?
        slide = options[:slide].to_i if options[:slide].present?

        if (options[:width].blank? && options[:height].present?) ||
           (options[:width].present? && options[:height].blank?) ||
           args.empty?
          raise 'The correct usage is {{slideshare(<key>[, width=x, height=y, slide=number])}}'
        end

        v = args[0]
        src = if slide > 0
                '//www.slideshare.net/slideshow/embed_code/' + v + '?startSlide=' + slide.to_s
              else
                '//www.slideshare.net/slideshow/embed_code/' + v
              end
        content_tag(:iframe, '', width: width, height: height, src: src, frameborder: 0, allowfullscreen: 'true')
      end
    end
  end
end
