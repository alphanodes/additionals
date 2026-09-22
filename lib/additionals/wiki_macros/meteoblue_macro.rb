# frozen_string_literal: true

module Additionals
  module WikiMacros
    module MeteoblueMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Display a weather forecast from meteoblue.

    Syntax:

    {{meteoblue(<location> [, days=4, width=216, height=368, color=BOOL, OPTIONS])}}

    Parameters:

      :param string location: weather location, e.g. münchen_deutschland_2867714. This is the part after
                              https://www.meteoblue.com/en/weather/forecast/week/
      :param int days: number of days (default 4)
      :param int width: widget width (default 216)
      :param int height: widget height (default 368)
      :param bool color: color (default) or monochrome (false)
      :param bool pictoicon, maxtemperature, mintemperature, precipitation, precipitationprobability, spot:
                  show this value (default true)
      :param bool windspeed, windgust, winddirection, uv, humidity, pressure: show this value (default false)

      The widget uses German for the German locale, English otherwise.

    Examples:

      {{meteoblue(münchen_deutschland_2867714)}}       weather for Munich

      {{meteoblue(münchen_deutschland_2867714, days=6, color=false)}} weather for Munich of the next 6 days without color

      {{meteoblue(münchen_deutschland_2867714, spot=false, pressure=true)}} weather for Munich without spot, with pressure
        DESCRIPTION

        macro :meteoblue do |_obj, args|
          args, options = extract_macro_options(args,
                                                :days,
                                                :width,
                                                :height,
                                                :color,
                                                :pictoicon,
                                                :maxtemperature,
                                                :mintemperature,
                                                :windspeed,
                                                :windgust,
                                                :winddirection,
                                                :uv,
                                                :humidity,
                                                :precipitation,
                                                :precipitationprobability,
                                                :pressure,
                                                :spot)

          raise 'The correct usage is {{meteoblue(<location>[, days=x, color=BOOL])}}' if args.empty?

          options[:days] = 4 if options[:days].blank?
          options[:coloured] = if RedminePluginKit.false? options[:color]
                                 'monochrome'
                               else
                                 'coloured'
                               end

          width = options[:width].presence || 216
          height = options[:height].presence || 368

          src = if current_language.to_s == 'de'
                  +'https://www.meteoblue.com/de/wetter/widget/daily/'
                else
                  +'https://www.meteoblue.com/en/weather/widget/daily/'
                end

          src << ERB::Util.url_encode(args[0])
          src << "?geoloc=fixed&days=#{options[:days]}&tempunit=CELSIUS&windunit=KILOMETER_PER_HOUR"
          src << "&precipunit=MILLIMETER&coloured=#{options[:coloured]}"

          src << Additionals.meteoblue_flag(options, :pictoicon, default: true)
          src << Additionals.meteoblue_flag(options, :maxtemperature, default: true)
          src << Additionals.meteoblue_flag(options, :mintemperature, default: true)
          src << Additionals.meteoblue_flag(options, :windspeed)
          src << Additionals.meteoblue_flag(options, :windgust)
          src << Additionals.meteoblue_flag(options, :winddirection)
          src << Additionals.meteoblue_flag(options, :uv)
          src << Additionals.meteoblue_flag(options, :humidity)
          src << Additionals.meteoblue_flag(options, :precipitation, default: true)
          src << Additionals.meteoblue_flag(options, :precipitationprobability, default: true)
          src << Additionals.meteoblue_flag(options, :spot, default: true)
          src << Additionals.meteoblue_flag(options, :pressure)

          tag.iframe width:, height:, src:, frameborder: 0
        end
      end
    end
  end

  def self.meteoblue_flag(options, name, default: false)
    enabled = options[name].blank? ? default : RedminePluginKit.true?(options[name])
    "&#{name}=#{enabled ? '1' : '0'}"
  end
end
