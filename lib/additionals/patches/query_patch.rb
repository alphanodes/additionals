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

        # list_optional is default: author_optional, assignee and user
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

        private

        def initialize_user_values_for_select2(field, values)
          return if Principal::SELECT2_FIELDS.exclude? @available_filters[field][:type]

          @available_filters[field][:values] = Principal.ids_to_names_with_ids values
        end
      end
    end
  end
end
