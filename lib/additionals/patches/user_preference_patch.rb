module Additionals
  module Patches
    module UserPreferencePatch
      extend ActiveSupport::Concern

      included do
        safe_attributes 'autowatch_involved_issue'
      end
    end
  end
end
