# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2016 AlphaNodes GmbH

require_dependency 'time_entry'

module RedmineTweaks
  module Patches
    module TimeEntryPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          validate :validate_issue_allowed
        end
      end

      module InstanceMethods
        def validate_issue_allowed
          return unless issue_id && issue && (issue.updated_on + 3.seconds) < Time.zone.now
          errors.add(:issue_id, :issue_log_time_not_allowed) unless issue.log_time_allowed?
        end
      end
    end
  end
end

unless TimeEntry.included_modules.include? RedmineTweaks::Patches::TimeEntryPatch
  TimeEntry.send(:include, RedmineTweaks::Patches::TimeEntryPatch)
end
