module Additionals
  module Patches
    module TimeEntryPatch
      def self.included(base)
        # no need to do this more than once.
        return if TimeEntry < InstanceMethods
        base.class_eval do
          prepend InstanceMethods
          validate :validate_issue_allowed
        end
      end

      module InstanceMethods
        def validate_issue_allowed
          return unless issue_id && issue
          return if Setting.commit_logtime_enabled? && (issue.updated_on + 3.seconds) > Additionals.now_with_user_time_zone
          errors.add(:issue_id, :issue_log_time_not_allowed) unless issue.log_time_allowed?
        end

        def editable_by?(usr)
          return false unless super
          return true unless issue_id && issue
          issue.log_time_allowed?
        end
      end
    end
  end
end
