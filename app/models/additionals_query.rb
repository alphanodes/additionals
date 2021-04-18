# frozen_string_literal: true

module AdditionalsQuery
  def column_with_prefix?(prefix)
    columns.detect { |c| c.name.to_s.start_with? "#{prefix}." }.present?
  end

  def available_column_names(only_sortable: false)
    names = available_columns.dup
    names.flatten!
    names.select! { |col| col.sortable.present? } if only_sortable
    names.map(&:name)
  end

  def sql_for_enabled_module(table_field, module_names)
    module_names = Array module_names

    sql = []
    module_names.each do |module_name|
      sql << "EXISTS(SELECT 1 FROM #{EnabledModule.table_name} WHERE #{EnabledModule.table_name}.project_id=#{table_field}" \
             " AND #{EnabledModule.table_name}.name='#{module_name}')"
    end

    sql.join ' AND '
  end

  def fix_sql_for_text_field(field, operator, value, table_name = nil, target_field = nil)
    table_name = queried_table_name if table_name.blank?
    target_field = field if target_field.blank?

    sql = []
    sql << "(#{sql_for_field field, operator, value, table_name, target_field})"
    sql << "#{table_name}.#{target_field} != ''" if operator == '*'

    sql.join ' AND '
  end

  def initialize_ids_filter(label: nil)
    if label
      add_available_filter 'ids', type: :integer, label: label
    else
      add_available_filter 'ids', type: :integer, name: '#'
    end
  end

  def sql_for_ids_field(_field, operator, value)
    if operator == '='
      # accepts a comma separated list of ids
      ids = value.first.to_s.scan(/\d+/).map(&:to_i)
      if ids.present?
        "#{queried_table_name}.id IN (#{ids.join ','})"
      else
        '1=0'
      end
    else
      sql_for_field 'id', operator, value, queried_table_name, 'id'
    end
  end

  def sql_for_project_identifier_field(field, operator, values)
    value = values.first
    values = value.split(',').map(&:strip) if ['=', '!'].include?(operator) && value.include?(',')
    sql_for_field field, operator, values, Project.table_name, 'identifier'
  end

  def sql_for_project_status_field(field, operator, value)
    sql_for_field field, operator, value, Project.table_name, 'status'
  end

  def initialize_project_identifier_filter
    return if project

    add_available_filter 'project.identifier',
                         type: :string,
                         name: l(:label_attribute_of_project, name: l(:field_identifier))
  end

  def initialize_project_status_filter
    return if project

    add_available_filter 'project.status',
                         type: :list,
                         name: l(:label_attribute_of_project, name: l(:field_status)),
                         values: -> { project_statuses_values }
  end

  def initialize_project_filter(always: false, position: nil)
    if project.nil? || always
      add_available_filter 'project_id', order: position,
                                         type: :list,
                                         values: -> { project_values }
    end
    return if project.nil? || project.leaf? || subproject_values.empty?

    add_available_filter 'subproject_id', order: position,
                                          type: :list_subprojects,
                                          values: -> { subproject_values }
  end

  def initialize_created_filter(position: nil, label: nil)
    add_available_filter 'created_on', order: position,
                                       type: :date_past,
                                       label: label
  end

  def initialize_updated_filter(position: nil, label: nil)
    add_available_filter 'updated_on', order: position,
                                       type: :date_past,
                                       label: label
  end

  def initialize_approved_filter
    add_available_filter 'approved',
                         type: :list,
                         values: [[l(:label_hrm_approved), '1'],
                                  [l(:label_hrm_not_approved), '0'],
                                  [l(:label_hrm_to_approval), '2'],
                                  [l(:label_hrm_without_approval), '3']],
                         label: :field_approved
  end

  def initialize_author_filter(position: nil)
    add_available_filter 'author_id', order: position,
                                      type: :list_optional,
                                      values: -> { author_values }
  end

  def initialize_assignee_filter(position: nil)
    add_available_filter 'assigned_to_id', order: position,
                                           type: :list_optional,
                                           values: -> { assigned_to_all_values }
  end

  def initialize_watcher_filter(position: nil)
    return unless User.current.logged?

    add_available_filter 'watcher_id', order: position,
                                       type: :list,
                                       values: -> { watcher_values_for_manage_public_queries }
  end

  # issue independend values. Use  assigned_to_values from Redmine, if you want it only for issues
  def assigned_to_all_values
    assigned_to_values = []
    assigned_to_values << ["<< #{l :label_me} >>", 'me'] if User.current.logged?
    assigned_to_values += principals.sort_by(&:status).collect { |s| [s.name, s.id.to_s, l("status_#{User::LABEL_BY_STATUS[s.status]}")] }

    assigned_to_values
  end

  # watcher_values of query checks view_issue_watchers, this checks manage_public_queries permission
  # and with users (not groups)
  def watcher_values_for_manage_public_queries
    watcher_values = [["<< #{l :label_me} >>", 'me']]
    watcher_values += users.collect { |s| [s.name, s.id.to_s] } if User.current.allowed_to? :manage_public_queries, project, global: true
    watcher_values
  end

  def sql_for_watcher_id_field(field, operator, value)
    watchable_type = queried_class == User ? 'Principal' : queried_class.to_s

    db_table = Watcher.table_name
    "#{queried_table_name}.id #{operator == '=' ? 'IN' : 'NOT IN'}" \
    " (SELECT #{db_table}.watchable_id FROM #{db_table} WHERE #{db_table}.watchable_type='#{watchable_type}' AND" \
    " #{sql_for_field field, '=', value, db_table, 'user_id'})"
  end

  def sql_for_is_private_field(_field, operator, value)
    if bool_operator operator, value
      return '' if value.count > 1

      "#{queried_table_name}.is_private = #{self.class.connection.quoted_true}"
    else
      return '1=0' if value.count > 1

      "#{queried_table_name}.is_private = #{self.class.connection.quoted_false}"
    end
  end

  # use for list fields with to values 1 (true) and 0 (false)
  def bool_operator(operator, values)
    operator == '=' && values.first == '1' || operator != '=' && values.first != '1'
  end

  # use for list
  def bool_values
    [[l(:general_text_yes), '1'], [l(:general_text_no), '0']]
  end

  def query_count
    objects_scope.count
  rescue ::ActiveRecord::StatementInvalid => e
    raise queried_class::StatementInvalid, e.message if defined? queried_class::StatementInvalid

    raise ::Query::StatementInvalid, e.message
  end

  def results_scope(**options)
    order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten!.to_a.reject(&:blank?)

    objects_scope(**options.except(:order, :limit, :offset))
      .order(order_option)
      .joins(joins_for_order_statement(order_option.join(',')))
      .limit(options[:limit])
      .offset(options[:offset])
  rescue ::ActiveRecord::StatementInvalid => e
    raise queried_class::StatementInvalid, e.message if defined? queried_class::StatementInvalid

    raise ::Query::StatementInvalid, e.message
  end

  def grouped_name_for(group_name, replace_fields = {})
    return unless group_name

    if grouped? && group_by_column.present?
      replace_fields.each do |field, new_name|
        return new_name.presence || group_name if group_by_column.name == field
      end
    end

    group_name
  end
end
