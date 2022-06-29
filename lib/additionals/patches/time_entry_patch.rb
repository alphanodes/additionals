# frozen_string_literal: true

module Additionals
  module Patches
    module TimeEntryPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
        include InstanceMethods

        validate :validate_issue_allowed
      end

      module InstanceOverwriteMethods
        def editable_by?(usr)
          return false unless super
          return true unless issue_id && issue

          issue.log_time_allowed?
        end
      end

      module InstanceMethods
        private

        def validate_issue_allowed
          return unless issue_id && issue
          # NOTE: do not use user time zone here, because issue do not use it
          return if Setting.commit_logtime_enabled? && (issue.updated_on + 5.seconds) > Time.current

          errors.add :issue_id, :issue_log_time_not_allowed unless issue.log_time_allowed?
        end
      end
    end
  end
end
