module AdditionalsJournalsHelper
  MultipleValuesDetail = Struct.new(:property, :prop_key, :custom_field, :old_value, :value)

  # Returns the textual representation of a journal details
  # as an array of strings
  def entity_details_to_strings(entity, details, options = {})
    entity_type = entity.model_name.param_key
    show_detail_method = "#{entity_type}_show_detail"
    options[:only_path] = options[:only_path] != false
    no_html = options.delete(:no_html)
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
      strings << send(show_detail_method, detail, no_html, options)
    end

    if values_by_field.present?
      values_by_field.each do |field, changes|
        if changes[:added].any?
          detail = MultipleValuesDetail.new('cf', field.id.to_s, field)
          detail.value = changes[:added]
          strings << send(show_detail_method, detail, no_html, options)
        end
        next unless changes[:deleted].any?

        detail = MultipleValuesDetail.new('cf', field.id.to_s, field)
        detail.old_value = changes[:deleted]
        strings << send(show_detail_method, detail, no_html, options)
      end
    end
    strings
  end

  # taken from Redmine 4
  # Returns the action links for an issue journal
  def render_entity_journal_actions(entity, journal)
    return '' unless journal.notes.present? && journal.editable_by?(User.current)

    entity_type = entity.model_name.param_key

    safe_join([link_to(l(:button_edit),
                       send("edit_#{entity_type}_journal_path", journal),
                       remote: true,
                       method: 'get',
                       title: l(:button_edit),
                       class: 'icon-only icon-edit'),
               link_to(l(:button_delete),
                       send("#{entity_type}_journal_path", journal, journal: { notes: '' }),
                       remote: true,
                       method: 'put', data: { confirm: l(:text_are_you_sure) },
                       title: l(:button_delete),
                       class: 'icon-only icon-del')], ' ')
  end
end
