class CreateDashboardDefaults < ActiveRecord::Migration[5.2]
  def up
    User.current = User.find_by(id: ENV['DEFAULT_USER_ID'].presence || User.admin.active.first.id)

    unless Dashboard.where(dashboard_type: DashboardContentWelcome::TYPE_NAME).exists?
      Dashboard.create! name: 'Welcome dashboard',
                        dashboard_type: DashboardContentWelcome::TYPE_NAME,
                        system_default: true,
                        author_id: User.current.id,
                        visibility: 2
    end

    return if Dashboard.where(dashboard_type: DashboardContentProject::TYPE_NAME).exists?

    Dashboard.create! name: 'Project dashboard',
                      dashboard_type: DashboardContentProject::TYPE_NAME,
                      system_default: true,
                      enable_sidebar: true,
                      author_id: User.current.id,
                      visibility: 2
  end
end
