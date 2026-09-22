# frozen_string_literal: true

module Additionals
  module WikiMacros
    module GpsMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Display GPS coordinates with links to OpenStreetMap, Google Maps and a Google Maps route.

    With GPS_MACRO_WITH_BAVARIA_ONLY enabled, links to BayernAtlas (bayern) and its
    hiking map (hike) are added.

    Syntax:

    {{gps(LAT, LON [, zoom=ZOOM, service=SERVICE, layer=LAYER, name=NAME])}}

    or

    {{gps(lat=LAT, lon=LON [, zoom=ZOOM, service=SERVICE, layer=LAYER, name=NAME])}}

    Parameters:

      :param string lat: latitude of location
      :param string lon: longitude of location
      :param int zoom: zoom level for osm (default 17) and bayern (default 12)
      :param string service: show only this service: osm, gmap, route (hike, bayern if enabled)
      :param string layer: BayernAtlas background layer for bayern (default vt_standard)
      :param string name: with service: link text, without service: replaces the "GPS" prefix

    Examples:

      {{gps(49.56083, 11.56018)}}
      {{gps(49.56083, 11.56018, zoom=12)}}
      {{gps(49.56083, 11.56018, service=osm)}}
      {{gps(lat=49.56083, lon=11.56018, service=gmap, name=Office)}}
        DESCRIPTION

        macro :gps do |_obj, args|
          args, options = extract_macro_options(args,
                                                :lat,
                                                :lon,
                                                :service,
                                                :name,
                                                :layer,
                                                :zoom)

          lat = options[:lat].presence || args&.first
          lon = options[:lon].presence || args&.second
          zoom = options[:zoom].presence || 17
          layer = options[:layer].presence || 'vt_standard'

          if lat.blank? || lon.blank?
            raise 'The correct usage is {{gps([lat=Latitude, lon=Longitude, service=SERVICE, name=NAME, zoom=ZOOM, layer: LAYER])}}'
          end

          links = {}
          links[:osm] = ['OSM',
                         "https://www.openstreetmap.org/?mlat=#{lat}&mlon=#{lon}#map=#{zoom}/#{lat}/#{lon}"]
          links[:gmap] = ['Gmap',
                          "https://maps.google.com/?q=#{lat},#{lon}&data=!3m1!1e3"]
          if AdditionalsConf.with_system_default 'GPS_MACRO_WITH_BAVARIA_ONLY', type: 'bool', default: false
            bavaria_zoom = options[:zoom].presence || 12

            links[:bayern] = ['Bayern',
                              "https://geoportal.bayern.de/bayernatlas/?E=#{lat}&N=#{lon}&zoom=#{bavaria_zoom}&bgLayer=#{layer}&crosshair=marker"]
            links[:hike] = ['Wandern',
                            "https://geoportal.bayern.de/bayernatlas/?E=#{lat}&N=#{lon}&zoom=#{bavaria_zoom}&bgLayer=vt_wandern&crosshair=marker"]
          end
          links[:route] = [l(:label_route),
                           "https://www.google.com/maps/dir/?api=1&destination=#{lat},#{lon}"]

          if options[:service].present?
            raise 'unknown service used' unless links.key? options[:service].to_sym

            link = links[options[:service].to_sym]
            return link_to_external options[:name], link.second if options[:name].present?

            tag.span safe_join(['GPS:', link_to_external("#{lat},#{lon}", link.second)], ' '), class: 'gps'
          else
            prefix = options[:name].presence || 'GPS'
            parts = ["#{prefix}:"]
            links.each_value do |link|
              parts << link_to_external(link.first, link.second)
            end
            tag.span safe_join(parts, ' '), class: 'gps'
          end
        end
      end
    end
  end
end
