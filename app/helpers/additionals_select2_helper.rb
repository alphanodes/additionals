module AdditionalsSelect2Helper
  def additionals_select2_tag(name, option_tags = nil, options = {})
    s = select_tag(name, option_tags, options)
    s << hidden_field_tag("#{name}[]", '') if options[:multiple] && options.fetch(:include_hidden, true)

    s + javascript_tag("select2Tag('#{sanitize_to_id(name)}', #{options.to_json});")
  end

  # Transforms select filters of +type+ fields into select2
  def additionals_transform_to_select2(type, options = {})
    javascript_tag("setSelect2Filter('#{type}', #{options.to_json});") unless type.empty?
  end
end
