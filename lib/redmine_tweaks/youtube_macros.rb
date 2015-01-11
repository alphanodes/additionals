# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015 AlphaNodes GmbH

module RedmineTweaks
  Redmine::WikiFormatting::Macros.register do
    
    desc <<-EOHELP
Youtube macro to include youtube video.

  Syntax:

  {{youtube(<video key>,[<width>,<height>,<autoplay>])}}

  Examples:

  {{youtube(KMU0tzLwhbE)}} show video with default size 640x360
  {{youtube(KMU0tzLwhbE,853,480)}} show video with user defined size
  {{youtube(KMU0tzLwhbE,853,480,1)}} show video with user defined size and autoplay video

EOHELP

    # Register youtube macro
    macro :youtube do |youtube_wiki_content, args|
      h = 360
      w = 640
      if args.length >= 1
        v = args[0]

        unless args[1].nil? || args[1].empty? || args[2].nil? || args[2].empty?
          w = args[1]
          h = args[2]
        end

        unless args[3].nil? || args[3] == 1
          src = "//www.youtube.com/embed/" + v + "?autoplay=1"
        else
          src = "//www.youtube-nocookie.com/embed/" + v
        end

        content_tag(:iframe, '', :width=>w, :height=>h, :src=>src, :frameborder=>0, :allowfullscreen=>"true" )
      else
        out = "<pre>Error in youtube macro. The correct usage is {{youtube(&lt;video key&gt;,[&lt;width&gt;,&lt;height&gt;])}}.</pre>"
      end

    end
  end
end
