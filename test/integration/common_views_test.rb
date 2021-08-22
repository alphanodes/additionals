# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class CommonViewsTest < Additionals::IntegrationTest
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :issue_statuses,
           :issues,
           :enumerations,
           :custom_fields,
           :custom_values,
           :custom_fields_trackers

  include Additionals::TestHelper

  def setup
    prepare_tests
  end

  test 'View user' do
    log_user 'admin', 'admin'
    get '/users/2'
    assert_response :success
  end

  test 'View issue' do
    log_user 'admin', 'admin'
    EnabledModule.create project_id: 1, name: 'issue_tracking'
    issue = issues :issues_001
    issue.description = 'new value'
    issue.save
    get '/issues/1'
    assert_response :success
  end
end
