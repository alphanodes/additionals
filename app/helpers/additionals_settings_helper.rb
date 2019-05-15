module AdditionalsSettingsHelper
  def additionals_settings_tabs
    tabs = [{ name: 'general', partial: 'additionals/settings/general', label: :label_general },
            { name: 'content', partial: 'additionals/settings/overview', label: :label_overview_page },
            { name: 'wiki', partial: 'additionals/settings/wiki', label: :label_wiki },
            { name: 'macros', partial: 'additionals/settings/macros', label: :label_macro_plural },
            { name: 'rules', partial: 'additionals/settings/issues', label: :label_issue_plural },
            { name: 'projects', partial: 'additionals/settings/projects', label: :label_project_plural },
            { name: 'users', partial: 'additionals/settings/users', label: :label_user_plural },
            { name: 'web', partial: 'additionals/settings/web_apis', label: :label_web_apis }]

    tabs << { name: 'menu', partial: 'additionals/settings/menu', label: :label_settings_menu } if User.current.try(:hrm_user_type_id).nil?

    tabs
  end

  def additionals_settings_checkbox(name, options = {})
    label_title = options.delete(:label).presence || l("label_#{name}")
    value = options.delete(:value)
    custom_value = if value.nil?
                     value = 1
                     false
                   else
                     true
                   end

    checked = custom_value ? @settings[name] : Additionals.true?(@settings[name])

    s = [label_tag("settings[#{name}]", label_title)]
    s << hidden_field_tag("settings[#{name}]", 0, id: nil) unless custom_value
    s << check_box_tag("settings[#{name}]", value, checked, options)
    safe_join(s)
  end

  def additionals_settings_textfield(name, options = {})
    label_title = options.delete(:label).presence || l("label_#{name}")
    value = options.delete(:value).presence || @settings[name]

    safe_join [label_tag("settings[#{name}]", label_title),
               text_field_tag("settings[#{name}]", value, options)]
  end

  def additionals_settings_textarea(name, options = {})
    label_title = options.delete(:label).presence || l("label_#{name}")
    value = options.delete(:value).presence || @settings[name]

    options[:class] = 'wiki-edit' unless options.key?(:class)
    options[:rows] = 8 unless options.key?(:rows)

    safe_join [label_tag("settings[#{name}]", label_title),
               text_area_tag("settings[#{name}]", value, options)]
  end
end
