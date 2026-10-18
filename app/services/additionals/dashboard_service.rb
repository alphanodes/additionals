# frozen_string_literal: true

module Additionals
  # Dashboards for programs: the dashboards the user can see, filtered like the
  # dashboard choice of the UI. Used by DashboardsController (API) and AI or
  # MCP tools, so both answer the same. The layout of a dashboard comes from
  # Dashboard#layout_export, which keeps stored settings from readers.
  #
  #   service = Additionals::DashboardService.new
  #   service.dashboards project: @project                    # project dashboards offered in the project
  #   service.dashboards dashboard_type: 'WelcomeDashboard'   # one type
  class DashboardService
    attr_reader :user

    def initialize(user: User.current)
      @user = user
    end

    # With a project the project dashboards of it and those for all projects,
    # as offered on the project overview
    def dashboards(project: nil, dashboard_type: nil)
      scope = Dashboard.visible(user).includes :author, :project
      scope = scope.where dashboard_type: dashboard_type if dashboard_type.present?
      if project
        scope = scope.project_only
        scope = scope.where(project_id: project.id).or(scope.where(project_id: nil))
      end
      scope.sorted
    end
  end
end
