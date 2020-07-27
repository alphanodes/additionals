module AdditionalsRoutesHelper
  def _dashboards_path(project, *args)
    if project
      project_dashboards_path(project, *args)
    else
      dashboards_path(*args)
    end
  end

  def _dashboard_path(project, *args)
    if project
      project_dashboard_path(project, *args)
    else
      dashboard_path(*args)
    end
  end

  def _dashboard_async_blocks_path(project, *args)
    if project
      project_dashboard_async_blocks_path(project, *args)
    else
      dashboard_async_blocks_path(*args)
    end
  end

  def _edit_dashboard_path(project, *args)
    if project
      edit_project_dashboard_path(project, *args)
    else
      edit_dashboard_path(*args)
    end
  end

  def _new_dashboard_path(project, *args)
    if project
      new_project_dashboard_path(project, *args)
    else
      new_dashboard_path(*args)
    end
  end

  def _update_layout_setting_dashboard_path(project, *args)
    if project
      update_layout_setting_project_dashboard_path(project, *args)
    else
      update_layout_setting_dashboard_path(*args)
    end
  end

  def _add_block_dashboard_path(project, *args)
    if project
      add_block_project_dashboard_path(project, *args)
    else
      add_block_dashboard_path(*args)
    end
  end

  def _remove_block_dashboard_path(project, *args)
    if project
      remove_block_project_dashboard_path(project, *args)
    else
      remove_block_dashboard_path(*args)
    end
  end

  def _order_blocks_dashboard_path(project, *args)
    if project
      order_blocks_project_dashboard_path(project, *args)
    else
      order_blocks_dashboard_path(*args)
    end
  end

  def dashboard_link_path(project, dashboard, options = {})
    options[:dashboard_id] = dashboard.id
    if dashboard.dashboard_type == DashboardContentProject::TYPE_NAME
      project_path project, options
    else
      home_path options
    end
  end
end
