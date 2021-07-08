# frozen_string_literal: true

module AdditionalsProjectsHelper
  def project_overview_name(_project, dashboard = nil)
    name = [l(:label_overview)]
    name << dashboard.name if dashboard.present? && (dashboard.always_expose? || !dashboard.system_default)

    safe_join name, Additionals::LIST_SEPARATOR
  end

  def render_api_includes(project, api)
    super
    api.enable_new_ticket_message project.enable_new_ticket_message
    api.new_ticket_message project.new_ticket_message
  end
end
