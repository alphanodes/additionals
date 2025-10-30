# frozen_string_literal: true

module Additionals
  module Patches
    module TimeEntryPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def assignable_users
          return super unless project

          # Use optimized implementation from AssignableUsersOptimizer for log_time users
          Additionals::AssignableUsersOptimizer.log_time_assignable_users project
        end
      end
    end
  end
end
