# frozen_string_literal: true

module AdditionalsRoutesHelper
  def _dashboards_path(project, *)
    if project
      project_dashboards_path(project, *)
    else
      dashboards_path(*)
    end
  end

  def _dashboard_path(project, *)
    if project
      project_dashboard_path(project, *)
    else
      dashboard_path(*)
    end
  end

  def _dashboard_async_blocks_path(project, *)
    if project
      project_dashboard_async_blocks_path(project, *)
    else
      dashboard_async_blocks_path(*)
    end
  end

  def _edit_dashboard_path(project, *)
    if project
      edit_project_dashboard_path(project, *)
    else
      edit_dashboard_path(*)
    end
  end

  def _new_dashboard_path(project, *)
    if project
      new_project_dashboard_path(project, *)
    else
      new_dashboard_path(*)
    end
  end

  def _update_layout_setting_dashboard_path(project, *)
    if project
      update_layout_setting_project_dashboard_path(project, *)
    else
      update_layout_setting_dashboard_path(*)
    end
  end

  def _add_block_dashboard_path(project, *)
    if project
      add_block_project_dashboard_path(project, *)
    else
      add_block_dashboard_path(*)
    end
  end

  def _remove_block_dashboard_path(project, *)
    if project
      remove_block_project_dashboard_path(project, *)
    else
      remove_block_dashboard_path(*)
    end
  end

  def _order_blocks_dashboard_path(project, *)
    if project
      order_blocks_project_dashboard_path(project, *)
    else
      order_blocks_dashboard_path(*)
    end
  end

  def dashboard_link_path(project, dashboard, **options)
    options[:dashboard_id] = dashboard.id

    case dashboard.dashboard_type
    when DashboardContentProject::TYPE_NAME
      project_path project, **options
    when DashboardContentWelcome::TYPE_NAME
      home_path(**options)
    else
      dashboard_type_name = dashboard.dashboard_type[0..-10]
      route_helper = "DashboardContent#{dashboard_type_name}::ROUTE_HELPER".constantize
      send route_helper, **options
    end
  end
end
