# frozen_string_literal: true

module AdditionalsSelect2Helper
  def additionals_select2_tag(name, option_tags, options)
    # No blank option for multiple selects: the hidden field below already
    # submits an empty value to clear the field, and select2's "clear all"
    # would otherwise select the blank option and render it as a stray empty
    # choice (#15425). This mirrors Redmine core's select_edit_tag convention.
    options[:include_blank] = false if options[:multiple]

    s = select_tag name, option_tags, options
    id = options.delete(:id) || sanitize_to_id(name)
    # Only append the array brackets when the name does not already end in
    # "[]" (as it does for multiple custom fields), otherwise the hidden field
    # name becomes "[][]" and Rack parses a nested ["", ...] value (#15425).
    if options[:multiple] && options.fetch(:include_hidden, true)
      hidden_name = name.to_s.end_with?('[]') ? name : "#{name}[]"
      s << hidden_field_tag(hidden_name, '', id: nil)
    end

    s + javascript_tag("select2Tag('#{id}', #{options.to_json});")
  end

  # Transforms select filters of +type+ fields into select2
  def additionals_transform_to_select2(type, options)
    javascript_tag "setSelect2Filter('#{type}', #{options.to_json});" unless type.empty?
  end
end
