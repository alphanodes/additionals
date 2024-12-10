# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class CommonViewsTest < Additionals::IntegrationTest
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

    assert_save issue

    get '/issues/1'

    assert_response :success
  end
end
