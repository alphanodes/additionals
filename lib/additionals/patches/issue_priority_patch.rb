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
          classes = [super, css_name_based_class]
          classes.join ' '
        end
      end

      module InstanceMethods
        # css class based on priority name
        def css_name_based_class
          css_name_based_classes.each do |name_class|
            return name_class[:name] if name_class[:words].any? { |s| s.casecmp(name).zero? }
          end
          'prio-name-other'
        end

        def css_name_based_classes
          @css_name_based_classes ||= [{ name: 'prio-name-low',
                                         words: [l(:default_priority_low), 'Low', 'Trivial', 'Niedrig', 'Gering'] },
                                       { name: 'prio-name-normal',
                                         words: [l(:default_priority_normal), 'Normal', 'Minor', 'Unwesentlich', 'Default'] },
                                       { name: 'prio-name-high',
                                         words: [l(:default_priority_high), 'High', 'Major', 'Important', 'Schwer', 'Hoch', 'Wichtig'] },
                                       { name: 'prio-name-urgent',
                                         words: [l(:default_priority_urgent), 'Urgent', 'Critical', 'Kritisch', 'Dringend'] },
                                       { name: 'prio-name-immediate',
                                         words: [l(:default_priority_immediate), 'Immediate', 'Blocker', 'Very high', 'Jetzt'] }]
        end
      end
    end
  end
end
