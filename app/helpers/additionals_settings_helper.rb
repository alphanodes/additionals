module AdditionalsSettingsHelper
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
end
