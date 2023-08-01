# frozen_string_literal: true

module AdditionalsProjectsHelper
  def project_overview_name(project, dashboard = nil)
    name = [l(:label_overview)]

    if dashboard.present? && (dashboard.always_expose? || !dashboard.system_default)
      default_dashboard = Dashboard.default DashboardContentProject::TYPE_NAME, project, User.current, ''
      name = [dashboard_link(default_dashboard, project, name: l(:label_overview))] if default_dashboard&.id != dashboard.id
      name << dashboard.name if dashboard.present? && (dashboard.always_expose? || !dashboard.system_default)
    end

    safe_join name, Additionals::LIST_SEPARATOR
  end

  def render_api_includes(project, api)
    super

    api.active_new_ticket_message project.active_new_ticket_message
    return unless User.current.allowed_to? :edit_project, project

    api.enable_new_ticket_message project.enable_new_ticket_message
    api.new_ticket_message project.new_ticket_message
  end
end
