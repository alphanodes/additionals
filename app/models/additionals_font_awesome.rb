# frozen_string_literal: true

class AdditionalsFontAwesome
  include Redmine::I18n

  FORMAT_REGEXP = /\Afa[rsb]_[a-zA-Z0-9]+[a-zA-Z0-9\-]*\z/.freeze
  SEARCH_LIMIT = 50

  class << self
    def load_icons(type)
      data = YAML.safe_load(ERB.new(IO.read(File.join(Additionals.plugin_dir, 'config', 'fontawesome_icons.yml'))).result) || {}
      icons = {}
      data.each do |key, values|
        icons[key] = { unicode: values['unicode'], label: values['label'] } if values['styles'].include? convert_type2style(type)
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
      info = value_info value
      return '' if info.blank?

      info[:classes]
    end

    def json_values(type)
      FONTAWESOME_ICONS[type].collect { |fa_symbol, values| { id: key2value(fa_symbol, type[-1]), text: values[:label] } }
    end

    def select_values(type)
      FONTAWESOME_ICONS[type].collect { |fa_symbol, values| [values[:label], key2value(fa_symbol, type[-1])] }
    end

    # show only one value as current selected
    # (all other options are retrieved by select2
    def active_option_for_select(selected)
      info = value_info selected, with_details: true
      return [] if info.blank?

      [[info[:label], selected]]
    end

    def value_info(value, with_details: false)
      return {} if value.blank?

      values = value.split '_'
      return {} unless values.count == 2

      info = { type: values[0].to_sym,
               name: "fa-#{values[1]}" }

      info[:classes] = "#{info[:type]} #{info[:name]}"
      info[:font_weight] = font_weight info[:type]
      info[:font_family] = font_family info[:type]

      if with_details
        info.merge! load_details(info[:type], values[1])
        return {} if info[:unicode].blank?
      end

      info
    end

    def search_for_select(search, selected = nil)
      # could be more then one
      selected_store = selected.to_s.split ','
      icons = search_in_type :far, search, selected_store
      cnt = icons.count
      return icons if cnt >= SEARCH_LIMIT

      icons += search_in_type :fas, search, selected_store, cnt
      cnt = icons.count
      return icons if cnt >= SEARCH_LIMIT

      icons + search_in_type(:fab, search, selected_store, cnt)
    end

    def convert2mermaid(icon)
      return if icon.blank?

      parts = icon.split '_'
      return unless parts.count == 2

      "#{parts.first}:fa-#{parts.last}"
    end

    private

    def search_in_type(type, search, selected_store, cnt = 0)
      icons = []

      search_length = search.to_s.length
      first_letter_search = if search_length == 1
                              search[0].downcase
                            elsif search_length.zero? && selected_store.any?
                              selected = selected_store.first
                              fa = selected.split '_'
                              search = fa[1][0] if fa.count > 1
                              search
                            end

      FONTAWESOME_ICONS[type].each do |fa_symbol, values|
        break if SEARCH_LIMIT == cnt

        id = key2value(fa_symbol, type[-1])
        next if selected_store.exclude?(id) &&
                search.present? &&
                (first_letter_search.present? && !values[:label].downcase.start_with?(first_letter_search) ||
                 first_letter_search.blank? && values[:label] !~ /#{search}/i)

        icons << { id: id, text: values[:label] }
        cnt += 1
      end

      icons
    end

    def load_details(type, name)
      return {} unless FONTAWESOME_ICONS.key? type

      values = FONTAWESOME_ICONS[type][name]
      return {} if values.blank?

      { unicode: "&#x#{values[:unicode]};".html_safe, label: values[:label] } # rubocop:disable Rails/OutputSafety
    end
  end
end
