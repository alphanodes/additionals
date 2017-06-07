require File.expand_path('../../test_helper', __FILE__)

class ProjectsControllerTest < ActionController::TestCase
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
           :enabled_modules

  def setup
    Setting.default_language = 'en'
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
  end

  def test_show_overview_content
    Setting.plugin_additionals = ActionController::Parameters.new(
      project_overview_content: 'Lore impsuum'
    )
    @request.session[:user_id] = 4
    get :show, id: 1

    assert_response :success
    assert_template 'show'
    assert_select 'div.project-content', text: /Lore impsuum/
  end

  def test_do_not_show_overview_content_box
    Setting.plugin_additionals = ActionController::Parameters.new(
      project_overview_content: ''
    )
    @request.session[:user_id] = 4
    get :show, id: 1

    assert_response :success
    assert_template 'show'
    assert_select 'div.project-content', count: 0
  end
end
