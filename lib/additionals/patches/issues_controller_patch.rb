require_dependency 'issues_controller'

module Additionals
  module Patches
    module IssuesControllerPatch
      def self.included(base)
        base.class_eval do
          helper :additionals_issues
        end
      end
    end
  end
end
