# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DashboardAsyncBlocksControllerTest < Additionals::ControllerTest
  fixtures :users, :email_addresses, :roles,
           :enumerations,
           :projects, :projects_trackers, :enabled_modules,
           :members, :member_roles,
           :issues, :issue_statuses, :issue_categories, :issue_relations,
           :versions,
           :trackers,
           :workflows,
           :custom_fields, :custom_values, :custom_fields_projects, :custom_fields_trackers,
           :time_entries,
           :watchers,
           :journals, :journal_details,
           :repositories, :changesets,
           :queries,
           :dashboards, :dashboard_roles

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
