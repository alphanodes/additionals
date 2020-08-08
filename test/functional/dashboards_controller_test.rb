require File.expand_path '../../test_helper', __FILE__

class DashboardsControllerTest < Additionals::ControllerTest
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :dashboards, :dashboard_roles,
           :queries

  def setup
    prepare_tests
    @request.session[:user_id] = 2
  end

  def test_create
    assert_difference 'Dashboard.count', 1 do
      post :create,
           params: { dashboard: { name: 'my test dashboard',
                                  dashboard_type: DashboardContentWelcome::TYPE_NAME,
                                  description: 'test desc',
                                  author_id: 2 } }
    end
  end
end
