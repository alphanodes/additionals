# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Display a google map.  Examples:

  Syntax:

  {{gmap([q=QUERY, mode=MODE, width=216, height=368])}}

  Examples:

    {{gmap(Munich)}} Google maps with Munich

    {{gmap(mode=directions, origin=Munich+Rosenheimerstr, destination=Arco)}} Direction from Munich to Arco
      DESCRIPTION

      macro :gmap do |_obj, args|
        src_options = %i[attribution_ios_deep_link_id
                         attribution_source
                         attribution_web_url
                         avoid
                         center
                         destination
                         fov
                         heading
                         language
                         location
                         maptype
                         origin
                         pano
                         pitch
                         region
                         units
                         waypoints
                         zoom]

        args, options = extract_macro_options(args,
                                              :mode,
                                              :width,
                                              :height,
                                              :attribution_ios_deep_link_id,
                                              :attribution_source,
                                              :attribution_web_url,
                                              :avoid,
                                              :center,
                                              :destination,
                                              :fov,
                                              :heading,
                                              :language,
                                              :location,
                                              :maptype,
                                              :origin,
                                              :pano,
                                              :pitch,
                                              :region,
                                              :units,
                                              :way_mode,
                                              :waypoints,
                                              :zoom)

        raise 'Missing Google Maps Embed API Key. See documentation for more info.' if Additionals.setting(:google_maps_api_key).blank?

        width = options[:width].presence || 620
        height = options[:height].presence || 350
        mode = options[:mode].presence || 'search'

        if mode == 'search' && options[:q].blank? && args.empty?
          raise 'The correct usage is {{gmap([q=QUERY, mode=MODE, widths=x, height=y])}}'
        end

        src = +"https://www.google.com/maps/embed/v1/#{mode}?key=" + Additionals.setting(:google_maps_api_key)
        if options[:q].present?
          src << "&q=#{ERB::Util.url_encode options[:q]}"
        elsif mode == 'search'
          src << "&q=#{ERB::Util.url_encode args[0]}"
        end

        src_options.each do |key|
          src << Additionals.gmap_flags(options, key)
        end
        src << "&#{mode}=" + ERB::Util.url_encode(options[:way_mode]) if options[:way_mode].present?

        tag.iframe width: width, height: height, src: src, frameborder: 0, allowfullscreen: 'true'
      end
    end
  end

  def self.gmap_flags(options, key)
    if options[key].present?
      "&#{key}=" + ERB::Util.url_encode(options[key])
    else
      ''
    end
  end
end
