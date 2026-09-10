# frozen_string_literal: true

module Additionals
  module Patches
    module QueriesHelperPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        # Render the issue category column as a link to the issue list of the
        # issue's project, filtered by this category. Falls back to the core
        # rendering when link_to_issue_category is not available in the current
        # helper context. The helper itself returns the plain category name when
        # the issue_link_category setting is disabled.
        def column_value(column, item, value)
          if column.name == :category && item.is_a?(Issue) && respond_to?(:link_to_issue_category)
            link_to_issue_category item, category: value
          else
            super
          end
        end
      end
    end
  end
end
