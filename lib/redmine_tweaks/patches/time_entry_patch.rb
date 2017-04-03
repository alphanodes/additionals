# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

require_dependency 'time_entry'

module RedmineTweaks
  module Patches
    module TimeEntryPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :editable_by?, :tweaks
          validate :validate_issue_allowed
        end
      end

      module InstanceMethods
        def validate_issue_allowed
          return unless issue_id && issue
          return if Setting.commit_logtime_enabled? && (issue.updated_on + 3.seconds) > Time.zone.now
          errors.add(:issue_id, :issue_log_time_not_allowed) unless issue.log_time_allowed?
        end

        def editable_by_with_tweaks?(usr)
          return false unless editable_by_without_tweaks?(usr)
          return true unless issue_id && issue
          issue.log_time_allowed?
        end
      end
    end
  end
end

unless TimeEntry.included_modules.include? RedmineTweaks::Patches::TimeEntryPatch
  TimeEntry.send(:include, RedmineTweaks::Patches::TimeEntryPatch)
end
