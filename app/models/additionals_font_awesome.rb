class AdditionalsFontAwesome
  include Redmine::I18n

  class << self
    def load_icons(type)
      data = YAML.safe_load(ERB.new(IO.read(Rails.root.join('plugins',
                                                            'additionals',
                                                            'config',
                                                            'fontawesome_icons.yml'))).result) || {}
      icons = {}
      data.each do |key, values|
        icons[key] = { unicode: values['unicode'], label: values['label'] } if values['styles'].include?(convert_type2style(type))
      end
      icons
    end

    def convert_type2style(type)
      case type
      when :fab
        'brands'
      when :far
        'regular'
      else
        'solid'
      end
    end

    def font_weight(key)
      case key
      when :fas
        900
      else
        'normal'
      end
    end

    def font_family(key)
      case key
      when :fab
        'Font Awesome\ 5 Brands'
      else
        'Font Awesome\ 5 Free'
      end
    end

    def key2value(key, type)
      "fa#{type}_" + key
    end

    def classes(value)
      info = value_info(value)
      return '' if info.blank?

      info[:classes]
    end

    def json_values(type)
      FONTAWESOME_ICONS[type].collect { |fa_symbol, values| { id: key2value(fa_symbol, type[-1]), text: values[:label] } }
    end

    def select_values(type)
      FONTAWESOME_ICONS[type].collect { |fa_symbol, values| [values[:label], key2value(fa_symbol, type[-1])] }
    end

    def json_for_select
      [{ text: l(:label_fontawesome_regular), children: json_values(:far) },
       { text: l(:label_fontawesome_solid), children: json_values(:fas) },
       { text: l(:label_fontawesome_brands), children: json_values(:fab) }].to_json
    end

    # show only one value as current selected
    # (all other options are retrieved by select2
    def active_option_for_select(selected)
      info = value_info(selected, with_details: true)
      return [] if info.blank?

      [[info[:label], selected]]
    end

    def options_for_select
      [[l(:label_fontawesome_regular), select_values(:far)],
       [l(:label_fontawesome_solid), select_values(:fas)],
       [l(:label_fontawesome_brands), select_values(:fab)]]
    end

    def value_info(value, options = {})
      return {} if value.blank?

      values = value.split('_')
      return {} unless values.count == 2

      info = { type: values[0].to_sym,
               name: "fa-#{values[1]}" }

      info[:classes] = "#{info[:type]} #{info[:name]}"
      info[:font_weight] = font_weight(info[:type])
      info[:font_family] = font_family(info[:type])

      if options[:with_details]
        info.merge!(load_details(info[:type], values[1]))
        return {} if info[:unicode].blank?
      end

      info
    end

    private

    def load_details(type, name)
      return {} unless FONTAWESOME_ICONS.key?(type)

      values = FONTAWESOME_ICONS[type][name]
      return {} if values.blank?

      { unicode: "&#x#{values[:unicode]};".html_safe, label: values[:label] } # rubocop:disable Rails/OutputSafety
    end
  end
end
