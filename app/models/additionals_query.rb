module AdditionalsQuery
  def self.included(base)
    base.send :include, InstanceMethods
  end

  module InstanceMethods
    def initialize_ids_filter(label)
      add_available_filter 'ids', type: :integer, label: label
    end

    def sql_for_ids_field(_field, operator, value)
      if operator == '='
        # accepts a comma separated list of ids
        ids = value.first.to_s.scan(/\d+/).map(&:to_i)
        if ids.present?
          "#{queried_table_name}.id IN (#{ids.join(',')})"
        else
          '1=0'
        end
      else
        sql_for_field('id', operator, value, queried_table_name, 'id')
      end
    end

    def watcher_values
      watcher_values = [["<< #{l(:label_me)} >>", 'me']]
      if project.nil? && User.current.allowed_to?(:manage_public_queries, nil, global: true) ||
         User.current.allowed_to?(:manage_public_queries, project)
        watcher_values += users.collect { |s| [s.name, s.id.to_s] }
      end
      watcher_values
    end

    def sql_for_watcher_id_field(field, operator, value)
      watchable_type = queried_class == User ? 'Principal' : queried_class.to_s

      db_table = Watcher.table_name
      "#{queried_table_name}.id #{operator == '=' ? 'IN' : 'NOT IN'}
        (SELECT #{db_table}.watchable_id FROM #{db_table} WHERE #{db_table}.watchable_type='#{watchable_type}' AND " +
        sql_for_field(field, '=', value, db_table, 'user_id') + ')'
    end

    def sql_for_tags_field(field, _operator, value)
      AdditionalsTag.sql_for_tags_field(queried_class, operator_for(field), value)
    end

    def sql_for_is_private_field(_field, operator, value)
      if bool_operator(operator, value)
        return '1=1' if value.count > 1

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
      raise StatementInvalid, e.message
    end

    def results_scope(options = {})
      order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

      objects_scope(options)
        .order(order_option)
        .joins(joins_for_order_statement(order_option.join(',')))
        .limit(options[:limit])
        .offset(options[:offset])
    rescue ::ActiveRecord::StatementInvalid => e
      raise StatementInvalid, e.message
    end
  end
end
