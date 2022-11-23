# frozen_string_literal: true

module Additionals
  module Patches
    module IssuePriorityPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
        include InstanceMethods
      end

      module InstanceOverwriteMethods
        def css_classes
          classes = super

          other_class = css_name_based_class
          return classes if other_class.blank?

          "#{classes} #{other_class}"
        end
      end

      module InstanceMethods
        # css class based on priority name
        def css_name_based_class
          if low?
            'priority-low-other' if position_name != 'lowest'
          else
            'priority-high-other' unless %w[default highest high2 high3].include? position_name
          end
        end
      end
    end
  end
end
