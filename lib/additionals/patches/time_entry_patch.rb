# frozen_string_literal: true

module Additionals
  module Patches
    module TimeEntryPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        alias_method :editable_by_without_additionals?, :editable_by?
        alias_method :editable_by?, :editable_by_with_additionals?
        validate :validate_issue_allowed
      end

      module InstanceMethods
        def validate_issue_allowed
          return unless issue_id && issue
          # NOTE: do not use user time zone here, because issue do not use it
          return if Setting.commit_logtime_enabled? && (issue.updated_on + 5.seconds) > Time.zone.now

          errors.add :issue_id, :issue_log_time_not_allowed unless issue.log_time_allowed?
        end

        def editable_by_with_additionals?(usr)
          return false unless editable_by_without_additionals? usr
          return true unless issue_id && issue

          issue.log_time_allowed?
        end
      end
    end
  end
end
