# frozen_string_literal: true

require_dependency 'welcome_controller'

module Additionals
  module Patches
    module WelcomeControllerPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        before_action :find_dashboard, only: %i[index]

        helper :additionals_routes
        helper :issues
        helper :queries
        helper :additionals_queries
        helper :additionals_settings
        helper :dashboards

        include DashboardsHelper
      end

      module InstanceMethods
        private

        def find_dashboard
          if params[:dashboard_id].present?
            begin
              @dashboard = Dashboard.welcome_only.find params[:dashboard_id]
              raise ::Unauthorized unless @dashboard.visible?
            rescue ActiveRecord::RecordNotFound
              return render_404
            end
          else
            @dashboard = Dashboard.default DashboardContentWelcome::TYPE_NAME
          end

          resently_used_dashboard_save @dashboard
          @can_edit = @dashboard&.editable?
          @dashboard_sidebar = dashboard_sidebar? @dashboard, params
        end
      end
    end
  end
end
