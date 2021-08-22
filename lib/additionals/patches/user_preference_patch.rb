# frozen_string_literal: true

module Additionals
  module Patches
    module UserPreferencePatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods
        safe_attributes 'autowatch_involved_issue', 'recently_used_dashboards'
      end

      module InstanceMethods
        def recently_used_dashboards
          self[:recently_used_dashboards]
        end

        def recently_used_dashboard(dashboard_type, project = nil)
          r = self[:recently_used_dashboards] ||= {}
          r = {} unless r.is_a? Hash

          return unless r.is_a?(Hash) && r.key?(dashboard_type)

          if dashboard_type == DashboardContentProject::TYPE_NAME
            r[dashboard_type][project.id]
          else
            r[dashboard_type]
          end
        end

        def recently_used_dashboards=(value)
          self[:recently_used_dashboards] = value
        end
      end
    end
  end
end
