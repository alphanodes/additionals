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
                       class: 'icon-only icon-del')], ' '
  end

  # Returns the textual representation of a single journal detail
  # rubocop: disable Rails/OutputSafety
  def entity_show_detail(entity, detail, no_html = false, **options) # rubocop:disable Style/OptionalBooleanParameter:
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

      html =
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
          s.html_safe
        elsif detail.value.present?
          if detail.old_value.present?
            l :text_journal_changed, label: label, old: old_value, new: value
          elsif multiple
            l :text_journal_added, label: label, value: value
          else
            l :text_journal_set_to, label: label, value: value
          end
        else
          l(:text_journal_deleted, label: label, old: old_value).html_safe
        end
      html.html_safe
    else
      # default implementation for journal detail rendering
      show_detail detail, no_html, options
    end
  end
  # rubocop: enable Rails/OutputSafety

  private

  def entity_show_detail_prop(detail, options)
    return options[:entity_prop] if options.key? :entity_prop
    return unless detail.property == 'cf'

    custom_field = detail.custom_field
    return unless custom_field

    return { show_diff: true, label: l(:field_description) } if custom_field.format.class.change_as_diff

    case custom_field.format.name
    when 'project_relation'
      prop = { label: custom_field.name }
      project = Project.visible.where(id: detail.value).first if detail.value.present?
      old_project = Project.visible.where(id: detail.old_value).first if detail.old_value.present?
      prop[:value] = link_to_project project if project.present?
      prop[:old_value] = link_to_project old_project if old_project.present?
    when 'db_entry'
      prop = { label: custom_field.name }
      db_entry = DbEntry.visible.where(id: detail.value).first if detail.value.present?
      old_db_entry = DbEntry.visible.where(id: detail.old_value).first if detail.old_value.present?
      prop[:value] = link_to db_entry.name, db_entry_url(db_entry) if db_entry.present?
      prop[:old_value] = link_to old_db_entry.name, db_entry_url(old_db_entry) if old_db_entry.present?
    when 'password'
      prop = { label: custom_field.name }
      password = Password.visible.where(id: detail.value).first if detail.value.present? && defined?(Password)
      old_password = Password.visible.where(id: detail.old_value).first if detail.old_value.present? && defined?(Password)
      prop[:value] = link_to password.name, password_url(password) if password.present?
      prop[:old_value] = link_to old_password.name, password_url(old_password) if old_password.present?
    end

    prop
  end
end
