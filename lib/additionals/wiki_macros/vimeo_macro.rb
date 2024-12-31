# frozen_string_literal: true

module Additionals
  module WikiMacros
    module VimeoMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Vimeo macro to include Vimeo video or show link to Vimeo video.

    Syntax:

      {{vimeo(<video key> [, width=640, height=360, autoplay=BOOL, mode=MODE, name=NAME, title=TITLE])}}

    Parameters:

      :param string video key: Vimeo video key, e.g. KMU0tzLwhbE.
      :param int width: width
      :param int height: height
      :param bool autoplay: autoplay video
      :param string mode: iframe or link
      :param string group: link video to group (only used with param mode = link)
      :param string name: name of link (only used with param mode = link)
      :param string title: title/mouseover of link (only used with param mode = link)

    Examples:

      {{vimeo(142849533)}} show video with default size 640x360
      {{vimeo(142849533, width=853, height=480)}} show video with user defined size
      {{vimeo(142849533, autoplay=true)}} autoplay video
      {{vimeo(142849533, mode=link)}} show link to Vimeo video
      {{vimeo(142849533, mode=link, name=Cool video)}} show link to Vimeo video and name it 'Cool video'
      {{vimeo(142849533, title=Cool video)}} use mouse over title 'Cool video' on video link
        DESCRIPTION

        macro :vimeo do |_obj, args|
          args, options = extract_macro_options args, :width, :height, :autoplay, :mode, :name, :title, :group

          width = options[:width].presence || 640
          height = options[:height].presence || 360

          raise 'The correct usage is {{vimeo(<video key>[, width=x, height=y, mode=MODE, name=NAME])}}' if args.empty?

          v = args[0]
          if options[:mode] == 'link'
            link = if options[:group].present?
                     "https://vimeo.com/groups/#{options[:group]}/videos/#{v}"
                   else
                     "https://vimeo.com/#{v}"
                   end

            link_to_external svg_icon_tag('youtube', label: options[:name] || 'Vimeo'),
                             link,
                             title: options[:title].presence,
                             class: 'video vimeo'
          else
            src = if RedminePluginKit.true? options[:autoplay]
                    "//player.vimeo.com/video/#{v}?autoplay=1"
                  else
                    "//player.vimeo.com/video/#{v}"
                  end
            tag.iframe width:, height:, src:, frameborder: 0, allowfullscreen: 'true'
          end
        end
      end
    end
  end
end
