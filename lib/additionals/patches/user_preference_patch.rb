module Additionals
  module Patches
    module UserPreferencePatch
      def self.included(base)
        base.class_eval do
          safe_attributes 'autowatch_involved_issue' if Redmine::VERSION.to_s >= '3.4'
        end
      end
    end
  end
end
