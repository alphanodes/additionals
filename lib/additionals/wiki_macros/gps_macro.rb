# frozen_string_literal: true

module Additionals
  module WikiMacros
    module GpsMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Display a GPS coordinates and link it to Google or Openstreetmap.

    Syntax:

    {{gps([q=QUERY, mode=MODE, width=216, height=368])}}

    Parameters:

      :param string lat: latitude of location
      :param string log: longitude of location
      :param string service: osm, gmap, route, bayern or all (default)
      :param int zoom: zoom level (only use for osm and bayern)
      :param string layer: layer to use
      :param string name: if specified, name is used as link name

    Examples:

      {{gps(49.56083,11.56018)}}
      {{gps(lat=49.56083,lon=11.56018)}}
        DESCRIPTION

        macro :gps do |_obj, args|
          args, options = extract_macro_options(args,
                                                :lat,
                                                :lon,
                                                :service,
                                                :name,
                                                :layers,
                                                :zoom)

          lat = options[:lat].presence || args&.first
          lon = options[:lon].presence || args&.second
          service = options[:service].presence || 'all'
          zoom = options[:zoom].presence || 17
          layers = options[:layers].presence || 'vt_standard'

          if lat.empty? || lon.empty?
            raise 'The correct usage is {{gps([lat=Latitude, lon=Longitude, service=SERVICE, name=NAME, zoom=ZOOM, layer: LAYER])}}'
          end

          # bayern_link = "https://atlas.bayern.de/?e=#{lat}&n=#{lon}&z=#{zoom}&r=0&l=luftbild_labels&t=bvv"
          bayern_link = "https://geoportal.bayern.de/bayernatlas/?E=#{lat}&N=#{lon}&zoom=13&bgLayer=#{layers}&crosshair=marker"
          gmap_link = "https://maps.google.com/?q=#{lat},#{lon}&data=!3m1!1e3"
          google_link = "https://www.google.com/maps/dir/?api=1&destination=#{lat},#{lon}"
          osm_link = "https://www.openstreetmap.org/?mlat=#{lat}&mlon=#{lon}#map=#{zoom}/#{lat}/#{lon}"

          case service
          when 'gmap'
            return link_to_external options[:name], src if options[:name].present?

            return tag.span safe_join(['GPS:', link_to_external("#{lat},#{lon}", gmap_link)], ' '), class: 'gps'
          when 'google'
            return link_to_external options[:name], src if options[:name].present?

            return tag.span safe_join(['GPS:', link_to_external("#{lat},#{lon}", google_link)], ' '), class: 'gps'
          when 'osm'
            return link_to_external options[:name], src if options[:name].present?

            return tag.span safe_join(['GPS:', link_to_external("#{lat},#{lon}", osm_link)], ' '), class: 'gps'
          else
            prefix = options[:name].presence || 'GPS'

            return tag.span safe_join(["#{prefix}:",
                                       link_to_external('OSM', osm_link),
                                       link_to_external('Gmap', gmap_link),
                                       link_to_external('Bayern', bayern_link),
                                       link_to_external(l(:label_route), google_link)], ' '), class: 'gps'
          end
        end
      end
    end
  end
end
