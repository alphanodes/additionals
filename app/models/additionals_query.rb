# frozen_string_literal: true

module AdditionalsQuery
  NO_RESULT_CONDITION = '1=0'
  WITH_TRUE_CONDITION = '1=1'

  def label_me_value
    self.class.label_me_value
  end

  def column_with_prefix?(prefix)
    columns.detect { |c| c.name.to_s.start_with? "#{prefix}." }.present?
  end

  def available_column_names(only_sortable: false, only_groupable: false, only_totalable: false, type: nil)
    method_name = ['available_']
    if type
      method_name << type
      method_name << '_'
    end
    method_name << 'columns'

    names = send(method_name.join).dup
    names.flatten!
    names.select! { |col| col.sortable.present? } if only_sortable
    names.select!(&:groupable?) if only_groupable
    names.select!(&:totalable) if only_totalable
    names.map(&:name)
  end

  def sql_for_enabled_module(table_field, module_names)
    module_names = Array module_names

    sql = module_names.map do |module_name|
      "EXISTS(SELECT 1 FROM #{EnabledModule.table_name} WHERE #{EnabledModule.table_name}.project_id=#{table_field}" \
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
      ids = ids_from_string value.first
      if ids.any?
        "#{queried_table_name}.id IN (#{ids.join ','})"
      else
        NO_RESULT_CONDITION
      end
    else
      sql_for_field 'id', operator, value, queried_table_name, 'id'
    end
  end

  def sql_for_project_name_field(field, operator, values)
    value = values.first
    values = value.strip_split if ['=', '!'].include?(operator) && value.include?(',')
    sql_for_field field, operator, values, Project.table_name, 'name'
  end

  def sql_for_project_identifier_field(field, operator, values)
    value = values.first
    values = value.strip_split if ['=', '!'].include?(operator) && value.include?(',')
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

  def initialize_project_name_filter
    return if project

    add_available_filter 'project.name',
                         type: :string,
                         name: l(:label_attribute_of_project, name: l(:field_name))
  end

  def initialize_project_status_filter
    return if project

    add_available_filter 'project.status',
                         type: :list,
                         name: l(:label_attribute_of_project, name: l(:field_status)),
                         values: -> { project_statuses_values }
  end

  def initialize_project_filter(always: false, position: nil, without_subprojects: false)
    if project.nil? || always
      add_available_filter 'project_id', order: position,
                                         type: :list,
                                         values: -> { project_values }
    end
    return if without_subprojects || project.nil? || project.leaf? || subproject_values.empty?

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
                                      type: :author
  end

  def initialize_assignee_filter(position: nil)
    add_available_filter 'assigned_to_id', order: position,
                                           type: :assignee
  end

  def initialize_watcher_filter(position: nil)
    return unless User.current.logged?

    add_available_filter 'watcher_id', order: position,
                                       type: :user_with_me
  end

  def initialize_last_notes_filter(order: nil)
    options = { type: :date_past,
                label: :label_last_notes }
    options[:order] = order if order
    add_available_filter 'last_notes', **options
  end

  def initialize_notes_count_filter(position: nil)
    add_available_filter 'notes_count',
                         order: position,
                         type: :integer
  end

  def sql_for_notes_count_field(_field, operator, value)
    sql_aggr_condition table: Journal.table_name,
                       values: value,
                       group_field: 'journalized_id',
                       operator: operator,
                       use_sub_query_for_all: true,
                       sub_query: "#{Journal.table_name} WHERE #{Journal.table_name}.journalized_id = #{queried_table_name}.id" \
                                  " AND #{Journal.table_name}.journalized_type = '#{queried_class.name}'" \
                                  " AND #{Journal.table_name}.notes IS NOT NULL" \
                                  " AND #{Journal.table_name}.notes !=''"
  end

  # not required for: assigned_to_id author_id user_id watcher_id updated_by last_updated_by
  # this fields are replaced by Query::statement
  def values_without_me(values)
    return values unless values.delete 'me'

    values << if User.current.logged?
                User.current.id.to_s
              else
                '0'
              end

    values
  end

  def initialize_notes_filter(position: nil)
    add_available_filter 'notes', type: :text, order: position
  end

  def sql_for_notes_field(field, operator, value)
    subquery = "SELECT 1 FROM #{Journal.table_name}" \
               " WHERE #{Journal.table_name}.journalized_type='#{queried_class}'" \
               " AND #{Journal.table_name}.journalized_id=#{queried_table_name}.id" \
               " AND (#{sql_for_field field, operator.sub(/^!/, ''), value, Journal.table_name, 'notes'})" \
               " AND (#{Journal.visible_notes_condition User.current, skip_pre_condition: true})"

    "#{/^!/.match?(operator) ? 'NOT EXISTS' : 'EXISTS'} (#{subquery})"
  end

  def sql_for_last_notes_field(field, operator, value)
    journalized_type = queried_class.name
    journal_table = Journal.table_name

    case operator
    when '*', '!*'
      op = operator == '*' ? 'EXISTS' : 'NOT EXISTS'
      "#{op}(SELECT 1 FROM #{queried_table_name} AS ii INNER JOIN #{journal_table}" \
        " ON #{journal_table}.journalized_id = ii.id AND #{journal_table}.journalized_type = '#{journalized_type}'" \
        " WHERE #{queried_table_name}.id = ii.id AND #{journal_table}.notes IS NOT NULL AND #{journal_table}.notes != '')"
    else
      "#{queried_table_name}.id IN (" \
      " SELECT #{journal_table}.journalized_id" \
      " FROM #{journal_table}" \
      " WHERE #{journal_table}.journalized_type='#{journalized_type}' AND #{journal_table}.id IN" \
      " (SELECT MAX(#{journal_table}.id)" \
      " FROM #{journal_table}" \
      " WHERE #{journal_table}.journalized_type='#{journalized_type}'" \
      " AND #{journal_table}.notes IS NOT NULL AND #{journal_table}.notes != ''" \
      " GROUP BY #{journal_table}.journalized_id)" \
      " AND #{sql_for_field field, operator, value, journal_table, 'created_on'})"
    end
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
      return NO_RESULT_CONDITION if value.count > 1

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

  # all results (without search_string limit)
  def query_count
    @query_count ||= search_string.present? ? objects_scope(search: search_string).count : objects_scope.count
  rescue ::ActiveRecord::StatementInvalid => e
    raise queried_class::StatementInvalid, e.message if defined? queried_class::StatementInvalid

    raise ::Query::StatementInvalid, e.message
  end

  def entries_init_options(**options)
    # set default limit to export limit, if limit is not set
    options[:limit] = export_limit unless options.key? :limit
    options[:search] = search_string if search_string
    options
  end

  # query results
  def entries(**_)
    raise 'overwrite it'
  end

  def results_scope(**options)
    order_option = [group_by_sort_order, options[:order] || sort_clause].flatten!.to_a.compact_blank

    objects_scope(**options.except(:order, :limit, :offset))
      .order(order_option)
      .joins(joins_for_order_statement(order_option.join(',')))
      .limit(options[:limit])
      .offset(options[:offset])
  rescue ::ActiveRecord::StatementInvalid => e
    raise queried_class::StatementInvalid, e.message if defined? queried_class::StatementInvalid

    raise ::Query::StatementInvalid, e.message
  end

  # NOTE: alias can be used, if results_scope is not usable (because it was overwritten)
  alias additionals_results_scope results_scope

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
