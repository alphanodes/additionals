# frozen_string_literal: true

module Additionals
  module Patches
    module QueriesHelperPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        alias_method :column_value_without_category_link, :column_value
        alias_method :column_value, :column_value_with_category_link
      end

      module InstanceMethods
        # Render the issue category column as a link to the issue list of the
        # issue's project, filtered by this category. Falls back to the core
        # rendering when link_to_issue_category is not available in the current
        # helper context. The helper itself returns the plain category name when
        # the issue_link_category setting is disabled.
        def column_value_with_category_link(column, item, value)
          if column.name == :category && item.is_a?(Issue) && respond_to?(:link_to_issue_category)
            link_to_issue_category item, category: value
          else
            column_value_without_category_link column, item, value
          end
        end
      end
    end
  end
end
