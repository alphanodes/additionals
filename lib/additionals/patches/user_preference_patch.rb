module Additionals
  module Patches
    module UserPreferencePatch
      def self.included(base)
        base.class_eval do
          safe_attributes 'autowatch_involved_issue'
        end
      end
    end
  end
end
