# frozen_string_literal: true

module AdditionalsJournalsHelper
  MultipleValuesDetail = Struct.new :property, :prop_key, :custom_field, :old_value, :value

  # Returns the textual representation of a journal details
  # as an array of strings
  def entity_details_to_strings(entity, details, **options)
    entity_type = entity.model_name.param_key
    show_detail_method = "#{entity_type}_show_detail"
    options[:only_path] = options[:only_path] != false
    no_html = options.delete :no_html
    strings = []
    values_by_field = {}

    details.each do |detail|
      if detail.property == 'cf'
        field = detail.custom_field
        if field&.multiple?
          values_by_field[field] ||= { added: [], deleted: [] }
          values_by_field[field][:deleted] << detail.old_value if detail.old_value
          values_by_field[field][:added] << detail.value if detail.value
          next
        end
      end
      strings << send(show_detail_method, detail, no_html, **options)
    end

    if values_by_field.present?
      values_by_field.each do |field, changes|
        if changes[:added].any?
          detail = MultipleValuesDetail.new 'cf', field.id.to_s, field
          detail.value = changes[:added]
          strings << send(show_detail_method, detail, no_html, **options)
        end
        next unless changes[:deleted].any?

        detail = MultipleValuesDetail.new 'cf', field.id.to_s, field
        detail.old_value = changes[:deleted]
        strings << send(show_detail_method, detail, no_html, **options)
      end
    end
    strings
  end

  # taken from Redmine 4
  # Returns the action links for an issue journal
  def render_entity_journal_actions(entity, journal)
    return '' unless journal.notes.present? && journal.editable_by?(User.current)

    entity_type = entity.model_name.param_key

    safe_join [link_to(l(:button_edit),
                       send(:"edit_#{entity_type}_journal_path", journal),
                       remote: true,
                       method: 'get',
                       title: l(:button_edit),
                       class: 'icon-only icon-edit'),
               link_to(l(:button_delete),
                       send(:"#{entity_type}_journal_path", journal, journal: { notes: '' }),
                       remote: true,
                       method: 'put', data: { confirm: l(:text_are_you_sure) },
                       title: l(:button_delete),
                       class: 'icon-only icon-del')], ' '
  end

  # Returns the textual representation of a single journal detail
  # rubocop: disable Style/OptionalBooleanParameter
  def entity_show_detail(entity, detail, no_html = false, **options)
    multiple = false
    no_detail = false
    show_diff = false
    label = nil
    diff_url_method = "diff_#{entity.name.underscore}_journal_url"
    entity_prop = entity_show_detail_prop detail, options

    if entity_prop.present?
      label = entity_prop[:label] if entity_prop.key? :label
      value = entity_prop[:value] if entity_prop.key? :value
      old_value = entity_prop[:old_value] if entity_prop.key? :old_value
      show_diff = entity_prop[:show_diff] if entity_prop.key? :show_diff
      no_detail = entity_prop[:no_detail] if entity_prop.key? :no_detail
    end

    if label || show_diff
      unless no_html
        label = tag.strong label
        old_value = tag.i old_value if detail.old_value
        old_value = tag.del old_value if detail.old_value && detail.value.blank?
        value = tag.i value if value
      end

      if no_detail
        l :text_journal_changed_no_detail, label: label
      elsif show_diff
        s = l :text_journal_changed_no_detail, label: label
        unless no_html
          diff_link = link_to l(:label_diff),
                              send(diff_url_method,
                                   detail.journal_id,
                                   detail_id: detail.id,
                                   only_path: options[:only_path]),
                              title: l(:label_view_diff)
          s << " (#{diff_link})"
        end
        s
      elsif detail.value.present?
        if detail.old_value.present?
          l :text_journal_changed, label: label, old: old_value, new: value
        elsif multiple
          l :text_journal_added, label: label, value: value
        else
          l :text_journal_set_to, label: label, value: value
        end
      else
        l :text_journal_deleted, label: label, old: old_value
      end.html_safe
    else
      # default implementation for journal detail rendering
      show_detail detail, no_html, options
    end
  end
  # rubocop: enable Style/OptionalBooleanParameter

  def render_email_attributes(entry, html: false)
    items = send :"email_#{entry.class.name.underscore}_attributes", entry, html
    if html
      tag.ul class: 'details' do
        items.map { |s| concat tag.li(s) }.join("\n")
      end
    else
      items.map { |s| "* #{s}" }.join("\n")
    end
  end

  def email_custom_field_values_attributes(entry, html)
    items = []
    entry.custom_field_values.each do |value|
      cf_value = show_value value, false
      next if cf_value.blank?

      items << if html
                 tag.strong("#{value.custom_field.name}: ") + cf_value
               else
                 "#{value.custom_field.name}: #{cf_value}"
               end
    end

    items
  end

  private

  def entity_show_detail_prop(detail, options)
    return options[:entity_prop] if options.key? :entity_prop
    return unless detail.property == 'cf'

    custom_field = detail.custom_field
    return unless custom_field

    { show_diff: true, label: detail.custom_field.name } if custom_field.format.class.change_as_diff
  end
end
