# frozen_string_literal: true

require_dependency 'projects_controller'

module Additionals
  module Patches
    module ProjectsControllerPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        before_action :find_dashboard, only: %i[show]

        helper :additionals_routes
        helper :issues
        helper :queries
        helper :additionals_queries
        helper :additionals_projects
        helper :additionals_settings
        helper :dashboards

        include DashboardsHelper
      end

      module InstanceMethods
        private

        def find_dashboard
          if params[:dashboard_id].present?
            begin
              @dashboard = Dashboard.project_only.find params[:dashboard_id]
              raise ::Unauthorized unless @dashboard.visible?
              raise ::Unauthorized unless @dashboard.project.nil? || @dashboard.project == @project
            rescue ActiveRecord::RecordNotFound
              return render_404
            end
          else
            @dashboard = Dashboard.default DashboardContentProject::TYPE_NAME, @project
          end

          @dashboard.content_project = @project
          resently_used_dashboard_save @dashboard, @project
          @can_edit = @dashboard&.editable?
          @dashboard_sidebar = dashboard_sidebar? @dashboard, params
        end
      end
    end
  end
end
