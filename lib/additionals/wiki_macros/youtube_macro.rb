# frozen_string_literal: true

module Additionals
  module WikiMacros
    module YoutubeMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Youtube macro to include a Youtube video or show a link to a Youtube video.

    Syntax:

      {{youtube(<video key> [, width=640, height=360, autoplay=BOOL, mode=MODE, name=NAME, title=TITLE])}}

    Parameters:

      :param string video key: Youtube video key, e.g. KMU0tzLwhbE
      :param int width: width (default 640)
      :param int height: height (default 360)
      :param bool autoplay: autoplay video
      :param string mode: iframe (default) or link
      :param string name: link text (only used with mode=link, default "Youtube")
      :param string title: title/mouseover of link (only used with mode=link)

    Examples:

      {{youtube(KMU0tzLwhbE)}} show video with default size 640x360
      {{youtube(KMU0tzLwhbE, width=853, height=480)}} show video with user defined size
      {{youtube(KMU0tzLwhbE, autoplay=true)}} autoplay video
      {{youtube(KMU0tzLwhbE, mode=link)}} show link to Youtube video
      {{youtube(KMU0tzLwhbE, mode=link, name=Cool video)}} show link to Youtube video and name it 'Cool video'
      {{youtube(KMU0tzLwhbE, mode=link, title=Cool video)}} use mouse over title 'Cool video' on video link
        DESCRIPTION

        macro :youtube do |_obj, args|
          args, options = extract_macro_options args, :width, :height, :autoplay, :mode, :name, :title

          width = options[:width].presence || 640
          height = options[:height].presence || 360

          raise 'The correct usage is {{youtube(<video key>[, width=x, height=y, mode=MODE, name=NAME])}}' if args.empty?

          v = args[0]
          if options[:mode] == 'link'
            link_to_external svg_icon_tag('youtube', label: options[:name] || 'Youtube'),
                             "https://www.youtube.com/watch?v=#{v}",
                             title: options[:title].presence,
                             class: 'video youtube'
          else
            src = if RedminePluginKit.true? options[:autoplay]
                    "//www.youtube.com/embed/#{v}?autoplay=1"
                  else
                    "//www.youtube-nocookie.com/embed/#{v}"
                  end
            tag.iframe width:, height:, src:, frameborder: 0, allowfullscreen: 'true'
          end
        end
      end
    end
  end
end
