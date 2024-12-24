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
      :param string service: google (default) or osm
      :param int zoom: zoom level (only use for osm)
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
                                                :zoom)

          lat = options[:lat].presence || args&.first
          lon = options[:lon].presence || args&.second
          service = options[:service].presence || 'both'
          zoom = options[:zoom].presence || 17

          raise 'The correct usage is {{gmap([q=QUERY, mode=MODE, widths=x, height=y])}}' if lat.empty? || lon.empty?

          google_link = "https://www.google.com/maps/dir/?api=1&destination=#{lat},#{lon}"
          osm_link = "https://www.openstreetmap.org/?mlat=#{lat}&mlon=#{lon}#map=#{zoom}/#{lat}/#{lon}"

          case service
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
                                       link_to_external('Gmap', google_link)], ' '), class: 'gps'
          end
        end
      end
    end
  end
end
