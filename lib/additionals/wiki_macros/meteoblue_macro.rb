# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Display current weather from meteoblue service.  Examples:

  Syntax:

  {{meteoblue(<location> [, days=INT, width=216, height=368, color=BOOL])}}

  Examples:

    {{meteoblue(münchen_deutschland_2867714)}}       weather for Munich

    {{meteoblue(münchen_deutschland_2867714, days=6, color=false)}} weather for Munich of the next 6 days without color
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
                                              :spot)

        raise 'The correct usage is {{meteoblue(<location>[, days=x, color=BOOL])}}' if args.empty?

        options[:days] = 4 if options[:days].blank?
        options[:coloured] = if options[:color].present? && !Additionals.true?(options[:color])
                               'monochrome'
                             else
                               'coloured'
                             end

        width = options[:width].presence || 216
        height = options[:height].presence || 368

        src = if User.current.language.blank? ? ::I18n.locale : User.current.language == 'de'
                +'https://www.meteoblue.com/de/wetter/widget/daily/'
              else
                +'https://www.meteoblue.com/en/weather/widget/daily/'
              end

        src << ERB::Util.url_encode(args[0])
        src << "?geoloc=fixed&days=#{options[:days]}&tempunit=CELSIUS&windunit=KILOMETER_PER_HOUR"
        src << "&precipunit=MILLIMETER&coloured=#{options[:coloured]}"

        src << Additionals.meteoblue_flag(options, :pictoicon, true)
        src << Additionals.meteoblue_flag(options, :maxtemperature, true)
        src << Additionals.meteoblue_flag(options, :mintemperature, true)
        src << Additionals.meteoblue_flag(options, :windspeed, false)
        src << Additionals.meteoblue_flag(options, :windgust, false)
        src << Additionals.meteoblue_flag(options, :winddirection, false)
        src << Additionals.meteoblue_flag(options, :uv, false)
        src << Additionals.meteoblue_flag(options, :humidity, false)
        src << Additionals.meteoblue_flag(options, :precipitation, true)
        src << Additionals.meteoblue_flag(options, :precipitationprobability, true)
        src << Additionals.meteoblue_flag(options, :spot, true)
        src << Additionals.meteoblue_flag(options, :pressure, false)

        tag.iframe width: width, height: height, src: src, frameborder: 0
      end
    end
  end

  def self.meteoblue_flag(options, name, default = tue)
    flag = +"#{name}="
    flag << if Additionals.true?(options[name]) || default
              '1'
            else
              '0'
            end
    flag
  end
end
