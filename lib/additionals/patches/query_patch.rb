# frozen_string_literal: true

module Additionals
  module Patches
    module QueryPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
        include InstanceMethods

        attr_accessor :search_string

        # list_optional is default, but required for short filters
        operators_by_filter_type[:author_optional] = operators_by_filter_type[:list_optional]
        operators_by_filter_type[:assignee] = operators_by_filter_type[:list_optional]
        operators_by_filter_type[:user] = operators_by_filter_type[:list_optional]

        operators_by_filter_type[:author] = operators_by_filter_type[:list]
        operators_by_filter_type[:global_user] = operators_by_filter_type[:list]
        operators_by_filter_type[:internal_user] = operators_by_filter_type[:list]
        operators_by_filter_type[:principal] = operators_by_filter_type[:list]
        operators_by_filter_type[:user_with_me] = operators_by_filter_type[:list]
      end

      class_methods do
        def additional_csv_separator
          l(:general_csv_separator) == ',' ? ';' : ','
        end

        def label_me_value
          [label_me, 'me']
        end

        def label_me
          "<< #{l :label_me} >>"
        end
      end

      module InstanceOverwriteMethods
        def add_filter(field, operator, values = nil)
          super
          return unless available_filters[field]

          initialize_user_values_for_select2 field, values

          # NOTE: true is required for short filter support!
          true
        end

        def add_available_filter(field, options)
          super
          values = filters&.dig(field, :values) || []
          initialize_user_values_for_select2 field, values

          @available_filters
        end
      end

      module InstanceMethods
        # Options of a query beyond those of core (filters, columns, grouping,
        # sorting, totals, display type) that plugins add, e.g. a counter box,
        # declared like settings (Additionals::SettingsSchema), so programs can
        # list and set them. A plugin extends these three methods with super;
        # rules are methods named query_option_<key>_<rule>, e.g.
        # query_option_color_schema_applies?(schema).
        def query_options_definitions
          {}
        end

        # The stored options as the query form sends them
        def query_option_values
          {}
        end

        # The params of the query form for option values (as stored), read by
        # build_from_params: a plugin writes its options the way its form does
        def query_option_params(_values)
          {}
        end

        # Hints about the stored options for a program, e.g. that an option
        # works only together with another one; empty when there is nothing to say
        def query_option_notes
          []
        end

        # The options with given values, completed by the stored ones
        def query_options_schema(values = {})
          definitions = Additionals::SettingsSchema.with_rule_methods query_options_definitions, self, prefix: 'query_option_'
          Additionals::SettingsSchema.new definitions, values, stored: query_option_values, query: self,
                                                               user: User.current, project:
        end

        def ids_from_string(string)
          string.to_s.scan(/\d+/).map(&:to_i)
        end

        def export_limit
          Setting.issues_export_limit.to_i
        end

        # Simple aggregation for counting all items in a table (no filtering)
        # Use sql_aggr_filtered when you need to filter items with a sub_query
        def sql_aggr(table:, group_field:, operator:, values:, **options)
          build_sql_aggr group_field:,
                         operator:,
                         values:,
                         sub_table: options[:sub_table] || table,
                         sub_query: options[:sub_table] || table,
                         having_table: options[:having_table] || table,
                         aggr: options[:aggr] || 'COUNT',
                         field: options[:field] || 'id',
                         join_field: options[:join_field] || options[:field] || 'id',
                         filtered: false,
                         debug: options[:debug]
        end

        # Filtered aggregation for counting items matching a sub_query filter
        # sub_query is REQUIRED and must contain a WHERE clause
        def sql_aggr_filtered(table:, sub_query:, group_field:, operator:, values:, **options)
          sub_table = options[:sub_table] || table

          build_sql_aggr group_field:,
                         operator:,
                         values:,
                         sub_table:,
                         sub_query:,
                         having_table: options[:having_table] || table,
                         aggr: options[:aggr] || 'COUNT',
                         field: options[:field] || 'id',
                         join_field: options[:join_field] || options[:field] || 'id',
                         filtered: true,
                         debug: options[:debug]
        end

        private

        def build_sql_aggr(group_field:, operator:, values:, sub_table:, sub_query:,
                           having_table:, aggr:, field:, join_field:, filtered:, debug:)
          if aggr == 'COUNT'
            first_value = values.first.to_i
            second_value = values[1].presence&.to_i
          else
            first_value = values.first.to_f
            second_value = values[1].presence&.to_f
          end

          # special case of 0 value
          operator = '!*' if operator == '=' && first_value.zero?

          compare_sql = "#{queried_table_name}.#{join_field}" \
                        " IN (SELECT #{sub_table}.#{group_field}" \
                        " FROM #{sub_query} GROUP BY #{sub_table}.#{group_field}" \
                        " HAVING #{aggr}(#{having_table}.#{field})"

          null_all_sql = if filtered
                           "#{sub_query} AND"
                         else
                           "#{sub_table} WHERE"
                         end

          null_all_sql << " #{sub_table}.#{group_field} = #{queried_table_name}.#{join_field})"

          sql = case operator
                when '='
                  "#{compare_sql} = #{first_value})"
                when '<='
                  "#{compare_sql} <= #{first_value})"
                when '>='
                  "#{compare_sql} >= #{first_value})"
                when '><'
                  "#{compare_sql} BETWEEN #{first_value} AND #{second_value})"
                when '!*'
                  "#{queried_table_name}.#{join_field} NOT IN (SELECT #{sub_table}.#{group_field}" \
                  " FROM #{null_all_sql}"
                when '*'
                  "#{queried_table_name}.#{join_field} IN (SELECT #{sub_table}.#{group_field}" \
                  " FROM #{null_all_sql}"
                end

          Additionals.debug sql if debug
          sql
        end

        def initialize_user_values_for_select2(field, values)
          return if Principal::SELECT2_FIELDS.exclude? @available_filters[field][:type]

          @available_filters[field][:values] = Principal.sorted.ids_to_names_with_ids values
        end
      end
    end
  end
end
