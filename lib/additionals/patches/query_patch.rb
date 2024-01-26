# frozen_string_literal: true

module Additionals
  module Patches
    module QueryPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        attr_accessor :search_string

        # NOTE: alias_method used with redmine_contacts
        alias_method :add_available_filter_without_additionals, :add_available_filter
        alias_method :add_available_filter, :add_available_filter_with_additionals

        # NOTE: alias_method used with redmine_contacts
        alias_method :add_filter_without_additionals, :add_filter
        alias_method :add_filter, :add_filter_with_additionals

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

      module InstanceMethods
        def add_filter_with_additionals(field, operator, values = nil)
          add_filter_without_additionals field, operator, values
          return unless available_filters[field]

          initialize_user_values_for_select2 field, values
          true
        end

        def add_available_filter_with_additionals(field, options)
          add_available_filter_without_additionals field, options
          values = filters[field].blank? ? [] : filters[field][:values]
          initialize_user_values_for_select2 field, values

          @available_filters
        end

        def ids_from_string(string)
          string.to_s.scan(/\d+/).map(&:to_i)
        end

        def export_limit
          Setting.issues_export_limit.to_i
        end

        def sql_aggr_condition(**options)
          raise 'missing table' unless options[:table]
          raise 'missing group_field' unless options[:group_field]

          options[:aggr] = 'COUNT' if options[:aggr].blank?
          options[:field] = 'id' if options[:field].blank?
          options[:operator] = '=' if options[:operator].blank?
          options[:sub_table] = options[:table] if options[:sub_table].blank?
          options[:sub_query] = options[:sub_table] if options[:sub_query].blank?
          options[:having_table] = options[:table] if options[:having_table].blank?
          options[:join_field] = options[:field] if options[:join_field].blank?

          if options[:aggr] == 'COUNT'
            first_value = options[:values].first.to_i
            second_value = options[:values][1].present? ? options[:values][1].to_i : nil
          else
            first_value = options[:values].first.to_f
            second_value = options[:values][1].present? ? options[:values][1].to_f : nil
          end

          # special case of 0 value
          options[:operator] = '!*' if options[:operator] == '=' && first_value.zero?

          compare_sql = "#{queried_table_name}.#{options[:join_field]}" \
                        " IN (SELECT #{options[:sub_table]}.#{options[:group_field]}" \
                        " FROM #{options[:sub_query]} GROUP BY #{options[:sub_table]}.#{options[:group_field]}" \
                        " HAVING #{options[:aggr]}(#{options[:having_table]}.#{options[:field]})"

          null_all_sql = if options[:use_sub_query_for_all]
                           +"#{options[:sub_query]} AND"
                         else
                           +"#{options[:sub_table]} WHERE"
                         end

          null_all_sql << " #{options[:sub_table]}.#{options[:group_field]} = #{queried_table_name}.#{options[:join_field]})"

          sql = case options[:operator]
                when '='
                  "#{compare_sql} = #{first_value})"
                when '<='
                  "#{compare_sql} <= #{first_value})"
                when '>='
                  "#{compare_sql} >= #{first_value})"
                when '><'
                  "#{compare_sql} BETWEEN #{first_value} AND #{second_value})"
                when '!*'
                  "#{queried_table_name}.#{options[:join_field]} NOT IN (SELECT #{options[:sub_table]}.#{options[:group_field]}" \
                  " FROM #{null_all_sql}"
                when '*'
                  "#{queried_table_name}.#{options[:join_field]} IN (SELECT #{options[:sub_table]}.#{options[:group_field]}" \
                  " FROM #{null_all_sql}"
                end

          Additionals.debug sql if options[:debug]
          sql
        end

        private

        def initialize_user_values_for_select2(field, values)
          return if Principal::SELECT2_FIELDS.exclude? @available_filters[field][:type]

          @available_filters[field][:values] = Principal.sorted.ids_to_names_with_ids values
        end
      end
    end
  end
end
