# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DashboardAsyncBlocksControllerTest < Additionals::ControllerTest
  fixtures :projects, :users, :email_addresses, :user_preferences,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_relations,
           :issue_statuses,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :journals, :journal_details,
           :dashboards, :dashboard_roles,
           :repositories, :changesets,
           :queries, :watchers

  include Redmine::I18n

  def setup
    prepare_tests
    Setting.default_language = 'en'

    @project = projects :projects_001
    @welcome_dashboard = dashboards :system_default_welcome
    @project_dashboard = dashboards :system_default_project
  end

  def test_query_blocks
    assert_dashboard_query_blocks [
      { dashboard_id: @welcome_dashboard.id, block: 'issuequery', entities_class: 'issues' },
      { dashboard_id: @project_dashboard.id, block: 'issuequery', project: @project, entities_class: 'issues' }
    ]
  end
end
