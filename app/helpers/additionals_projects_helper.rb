# frozen_string_literal: true

module AdditionalsProjectsHelper
  def project_overview_name(_project, dashboard = nil)
    name = [l(:label_overview)]
    name << dashboard.name if dashboard.present? && (dashboard.always_expose? || !dashboard.system_default)

    safe_join name, Additionals::LIST_SEPARATOR
  end
end
