class AdditionalsFontAwesome
  include Redmine::I18n

  class << self
    def load_icons(type)
      data = YAML.safe_load(ERB.new(IO.read(Rails.root.join('plugins',
                                                            'additionals',
                                                            'config',
                                                            "fa_#{type}.yml"))).result) || {}
      data['icons']
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

    def key2name(key)
      'fa-' + key.tr('_', '-')
    end

    def key2value(key, type)
      "fa#{type}-" + key
    end

    def classes(value)
      info = value_info(value)
      return '' if info.blank?
      info[:classes]
    end

    def json_values(type)
      FONTAWESOME_ICONS[type].collect { |fa_symbol, _v| { id: key2value(fa_symbol, type[-1]), text: key2name(fa_symbol) } }
    end

    def select_values(type)
      FONTAWESOME_ICONS[type].collect { |fa_symbol, _v| [key2name(fa_symbol), key2value(fa_symbol, type[-1])] }
    end

    def search_unicode(type, name)
      return unless FONTAWESOME_ICONS.key?(type)
      code = FONTAWESOME_ICONS[type][name]
      "&#x#{code}".html_safe if code.present?
    end

    def json_for_select
      values = []
      values << { text: l(:label_fontawesome_regular), children: json_values(:far) }
      values << { text: l(:label_fontawesome_solid), children: json_values(:fas) }
      values << { text: l(:label_fontawesome_brands), children: json_values(:fab) }

      values.to_json
    end

    # show only one value as current selected
    # (all other options are retrieved by select2
    def active_option_for_select(selected)
      info = value_info(selected)
      return [] if info.blank?
      [[info[:name], selected]]
    end

    def options_for_select
      values = []
      values << [l(:label_fontawesome_regular), select_values(:far)]
      values << [l(:label_fontawesome_solid), select_values(:fas)]
      values << [l(:label_fontawesome_brands), select_values(:fab)]
      values
    end

    def value_info(value, options = {})
      info = {}
      return [] if value.blank?
      values = value.split('-')
      return [] unless values.count == 2
      info[:type] = values[0].to_sym
      info[:name] = key2name(values[1])
      info[:classes] = "#{info[:type]} #{info[:name]}"
      info[:font_weight] = font_weight(info[:type])
      info[:font_family] = font_family(info[:type])
      if options[:with_unicode]
        info[:unicode] = search_unicode(info[:type], values[1])
        return [] if info[:unicode].blank?
      end
      info
    end
  end
end
