# frozen_string_literal: true

class CreateDashboardDefaults < ActiveRecord::Migration[5.2]
  # Resolve the user that owns the default dashboards. Uses DEFAULT_USER_ID if
  # set, otherwise the first active admin (created by Redmine core migration
  # 001_setup, which runs before plugin migrations). Raises a clear error
  # instead of a NoMethodError when no usable user is found.
  def self.dashboard_author
    author_id = ENV['DEFAULT_USER_ID'].presence
    author = author_id ? User.find_by(id: author_id) : User.admin.active.first
    return author if author

    raise 'No user found to own the default dashboards. ' \
          'Set DEFAULT_USER_ID to an existing user id and re-run the migration.'
  end

  def up
    User.current = self.class.dashboard_author

    unless Dashboard.exists? dashboard_type: DashboardContentWelcome::TYPE_NAME
      puts 'Creating welcome default dashboard'
      Dashboard.create! name: 'Welcome dashboard',
                        dashboard_type: DashboardContentWelcome::TYPE_NAME,
                        system_default: true,
                        author_id: User.current.id,
                        visibility: 2
    end

    return if Dashboard.exists? dashboard_type: DashboardContentProject::TYPE_NAME

    puts 'Creating project default dashboard'
    Dashboard.create! name: 'Project dashboard',
                      dashboard_type: DashboardContentProject::TYPE_NAME,
                      system_default: true,
                      enable_sidebar: true,
                      author_id: User.current.id,
                      visibility: 2

    raise 'Default dashboard are not created. Solve database problems and re-run migration!' unless Dashboard.count == 2
  end

  def down; end
end
