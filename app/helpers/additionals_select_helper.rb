# frozen_string_literal: true

module AdditionalsSelectHelper
  # Options of additionals_select_tag that configure the select field, all
  # others go to the <select> element
  SELECT_FIELD_OPTIONS = %i[url tags scoped_tags free_input free_input_pattern renderer value_key
                            placeholder allow_clear min_input_length width suggestion].freeze
  BLANK_OPTION = /<option[^>]*\svalue=(""|'')/

  # Select field with search, entries from the server (+url+), tags and
  # multiple values. The field is set up in the browser by the Stimulus
  # controller additionals-select; plugins never talk to the library behind it.
  #
  # renderer: name_with_icon (default), avatar, contact, icon or color_scheme
  # value_key: property of the server entries that becomes the value
  # free_input: takes typed text as value (free_input_pattern: a regular
  # expression the text has to match)
  def additionals_select_tag(name, option_tags = nil, **options)
    field_options = options.extract!(*SELECT_FIELD_OPTIONS)
    multiple = options[:multiple]
    include_hidden = options.delete :include_hidden

    # No blank option for multiple selects: the hidden field below already
    # submits an empty value to clear the field, and "clear all" would otherwise
    # select the blank option and show it as a stray empty choice. This mirrors
    # Redmine core's select_edit_tag convention.
    options[:include_blank] = false if multiple
    options[:include_blank] = true if options[:include_blank].nil? && clear_needs_blank_option?(field_options, multiple, option_tags)
    options[:data] = additionals_select_data options[:data], **field_options

    s = [additionals_library_load(:select_fields), select_tag(name, option_tags, options)]
    # Only append the array brackets when the name does not already end in
    # "[]" (as it does for multiple custom fields), otherwise the hidden field
    # name becomes "[][]" and Rack parses a nested ["", ...] value.
    if multiple && include_hidden != false
      hidden_name = name.to_s.end_with?('[]') ? name : "#{name}[]"
      s << hidden_field_tag(hidden_name, '', id: nil)
    end
    safe_join s
  end

  # Select fields for the values of query filters, registered by filter type
  # (+type+, e.g. a type of the plugin like 'author'), by custom field format
  # (+field_format+) or by filter name (+field+). Takes the options of
  # additionals_select_tag; filters choose multiple values unless
  # multiple: false.
  def additionals_select_filter(type: nil, field_format: nil, field: nil, **field_options)
    keys = { type:, fieldFormat: field_format, field: }.compact
    raise ArgumentError, 'exactly one of type, field_format or field is required' unless keys.size == 1

    return unless additionals_select_fields?

    kind, name = keys.first
    options = field_options.compact
                           .transform_keys { |key| key.to_s.camelize :lower }
                           .transform_values { |value| additionals_select_value value }
    safe_join [additionals_library_load(:select_fields),
               javascript_tag("additionalsSelectRegisterFilter(#{kind.to_s.to_json}, #{name.to_s.to_json}, #{options.to_json});")]
  end

  # data attributes of a select field, for selects of a form builder
  # (form.select ..., data: additionals_select_data(renderer: 'icon')), which
  # need the library loaded with additionals_library_load(:select_fields)
  def additionals_select_data(data = nil, **field_options)
    data = (data || {}).dup
    data[:controller] = [data[:controller], 'additionals-select'].compact_blank.join ' '
    field_options.each do |key, value|
      next if value.nil? || value == false || value == ''

      data[:"additionals_select_#{key}_value"] = additionals_select_value value
    end
    data
  end

  # Texts of the select fields in the language of the page, the library has
  # English ones of its own
  def additionals_select_labels
    { search: l(:label_search),
      noResults: l(:label_no_data),
      clear: l(:button_clear),
      remove: l(:button_remove) }
  end

  private

  # Clearing a single field goes back to its blank option. Without one nothing
  # is selected, the form leaves the field out and the old value stays.
  def clear_needs_blank_option?(field_options, multiple, option_tags)
    field_options[:allow_clear] && !multiple && !option_tags.to_s.match?(BLANK_OPTION)
  end

  # A Regexp (free_input_pattern) is checked in the browser by its source
  def additionals_select_value(value)
    value.is_a?(Regexp) ? value.source : value
  end
end
