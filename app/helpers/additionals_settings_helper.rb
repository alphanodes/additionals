module AdditionalsSettingsHelper
  def additionals_settings_tabs
    tabs = [{ name: 'general', partial: 'additionals/settings/general', label: :label_general },
            { name: 'wiki', partial: 'additionals/settings/wiki', label: :label_wiki },
            { name: 'macros', partial: 'additionals/settings/macros', label: :label_macro_plural },
            { name: 'rules', partial: 'additionals/settings/issues', label: :label_issue_plural },
            { name: 'web', partial: 'additionals/settings/web_apis', label: :label_web_apis }]

    unless Redmine::Plugin.installed? 'redmine_hrm'
      tabs << { name: 'menu', partial: 'additionals/settings/menu', label: :label_settings_menu }
    end

    tabs
  end

  def additionals_settings_checkbox(name, options = {})
    active_value = options.delete(:active_value).presence || @settings.present? && @settings[name]
    tag_name = options.delete(:tag_name).presence || "settings[#{name}]"

    label_title = options.delete(:label).presence || l("label_#{name}")
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
                Additionals.true? active_value
              end

    s = [label_tag(tag_name, label_title)]
    s << hidden_field_tag(tag_name, 0, id: nil) if !custom_value || value_is_bool
    s << check_box_tag(tag_name, value, checked, options)
    safe_join s
  end

  def additionals_settings_textfield(name, options = {})
    label_title = options.delete(:label).presence || l("label_#{name}")
    value = options.delete(:value).presence || @settings[name]

    safe_join [label_tag("settings[#{name}]", label_title),
               text_field_tag("settings[#{name}]", value, options)]
  end

  def additionals_settings_passwordfield(name, options = {})
    label_title = options.delete(:label).presence || l("label_#{name}")
    value = options.delete(:value).presence || @settings[name]

    safe_join [label_tag("settings[#{name}]", label_title),
               password_field_tag("settings[#{name}]", value, options)]
  end

  def additionals_settings_urlfield(name, options = {})
    label_title = options.delete(:label).presence || l("label_#{name}")
    value = options.delete(:value).presence || @settings[name]

    safe_join [label_tag("settings[#{name}]", label_title),
               url_field_tag("settings[#{name}]", value, options)]
  end

  def additionals_settings_textarea(name, options = {})
    label_title = options.delete(:label).presence || l("label_#{name}")
    value = options.delete(:value).presence || @settings[name]

    options[:class] = 'wiki-edit' unless options.key?(:class)
    options[:rows] = addtionals_textarea_cols(value) unless options.key?(:rows)

    safe_join [label_tag("settings[#{name}]", label_title),
               text_area_tag("settings[#{name}]", value, options)]
  end
end
