# frozen_string_literal: true

module Additionals
  module WikiMacros
    module GmapMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Display a Google map (requires a Google Maps Embed API key in the additionals settings).

    Syntax:

    {{gmap(QUERY [, mode=MODE, width=620, height=350, OPTIONS])}}
    {{gmap(q=QUERY [, mode=MODE, width=620, height=350, OPTIONS])}}

    Parameters:

      :param string QUERY, q: location to search for (required for modes search and place)
      :param string mode: search (default), place, directions, view or streetview
      :param int width: widget width (default 620)
      :param int height: widget height (default 350)
      :param string origin, destination, waypoints, avoid, units: used by mode directions
      :param string way_mode: travel mode for mode directions: driving, walking, bicycling, transit or flying
      :param string center, zoom, maptype: used by mode view
      :param string location, pano, heading, pitch, fov: used by mode streetview
      :param string language, region: language and region of the map

    Examples:

      {{gmap(Munich)}} Google map with Munich
      {{gmap(mode=place, q=Eiffel Tower)}} Google map with the place Eiffel Tower
      {{gmap(mode=directions, origin=Munich+Rosenheimerstr, destination=Arco)}} Directions from Munich to Arco
      {{gmap(mode=directions, origin=Munich, destination=Arco, way_mode=bicycling)}} Directions by bicycle
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
                                                :q,
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

          src = "https://www.google.com/maps/embed/v1/#{mode}?key=" + Additionals.setting(:google_maps_api_key)
          if options[:q].present?
            src << "&q=#{ERB::Util.url_encode options[:q]}"
          elsif mode == 'search'
            src << "&q=#{ERB::Util.url_encode args[0]}"
          end

          src_options.each do |key|
            src << Additionals.gmap_flags(options, key)
          end
          src << "&mode=#{ERB::Util.url_encode options[:way_mode]}" if options[:way_mode].present?

          tag.iframe width:, height:, src:, frameborder: 0, allowfullscreen: 'true'
        end
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
