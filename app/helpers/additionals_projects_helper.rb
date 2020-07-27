module AdditionalsProjectsHelper
  def project_overview_name(_project, dashboard = nil)
    name = [l(:label_overview)]
    if dashboard.present?
      name << dashboard.name if dashboard.always_expose? || !dashboard.system_default
    end

    safe_join name, Additionals::LIST_SEPARATOR
  end
end
