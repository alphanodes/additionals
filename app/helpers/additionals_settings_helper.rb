# frozen_string_literal: true

module AdditionalsSettingsHelper
  def additionals_settings_checkbox(name, **options)
    active_value = options.delete(:active_value).presence || @settings.present? && @settings[name]
    tag_name = options.delete(:tag_name).presence || "settings[#{name}]"

    value = options.delete :value
    value_is_bool = options.delete :value_is_bool
    custom_value = if value.nil?
                     value = 1
                     false
                   else
                     value = 1 if value_is_bool
                     true
                   end

    checked = if custom_value && !value_is_bool
                active_value
              else
                RedminePluginKit.true? active_value
              end

    s = [label_tag(tag_name, additionals_settings_label(name, options))]
    s << hidden_field_tag(tag_name, 0, id: nil) if !custom_value || value_is_bool
    s << check_box_tag(tag_name, value, checked, **options)
    safe_join s
  end

  def additionals_settings_numberfield(name, **options)
    additionals_settings_input_field :number_field_tag, name, **options
  end

  def additionals_settings_textfield(name, **options)
    additionals_settings_input_field :text_field_tag, name, **options
  end

  def additionals_settings_passwordfield(name, **options)
    additionals_settings_input_field :password_field_tag, name, **options
  end

  def additionals_settings_urlfield(name, **options)
    additionals_settings_input_field :url_field_tag, name, **options
  end

  def additionals_settings_timefield(name, **options)
    additionals_settings_input_field :time_field_tag, name, **options
  end

  def additionals_settings_select(name, values, **options)
    tag_name = options.delete(:tag_name).presence || "settings[#{name}]"
    safe_join [label_tag(tag_name, additionals_settings_label(name, options)),
               select_tag(tag_name, values, **options)]
  end

  def additionals_settings_textarea(name, **options)
    value = if options.key? :value
              options.delete :value
            elsif @settings.present?
              @settings[name]
            end

    options[:class] = 'wiki-edit' unless options.key? :class
    options[:rows] = addtionals_textarea_cols value unless options.key? :rows

    safe_join [label_tag("settings[#{name}]", additionals_settings_label(name, options)),
               text_area_tag("settings[#{name}]", value, **options)]
  end

  # NOTE: overwrite redmine to use showSettingsTab instead of showTab to support tabs for plugins
  def get_tab_action(tab)
    return super if action_name != 'plugin'

    if tab[:onclick]
      tab[:onclick]
    elsif tab[:partial]
      "showPluginSettingsTab('#{tab[:name]}', this.href)"
    end
  end

  private

  def additionals_settings_label(name, options)
    label = options.delete :label
    label_title = if label.present?
                    [label.is_a?(Symbol) ? l(label) : label]
                  else
                    [l("label_#{name}")]
                  end

    label_title << tag.span('*', class: 'required') if options[:required].present?
    safe_join label_title, ' '
  end

  def additionals_settings_input_field(tag_field, name, **options)
    tag_name = options.delete(:tag_name).presence || "settings[#{name}]"
    default_setting = options.delete :default_setting

    value = if options.key? :value
              options.delete :value
            elsif @settings.present? && @settings.key?(name)
              @settings[name]
            elsif default_setting
              default_setting
            end

    safe_join [label_tag(tag_name, additionals_settings_label(name, options)),
               send(tag_field, tag_name, value, **options)], ' '
  end
end
