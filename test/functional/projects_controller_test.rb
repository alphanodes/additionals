require File.expand_path('../../test_helper', __FILE__)

class ProjectsControllerTest < Additionals::ControllerTest
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
    User.current = nil
  end

  def test_show_overview_content
    with_additionals_settings(project_overview_content: 'Lore impsuum') do
      @request.session[:user_id] = 4
      get :show,
          params: { id: 1 }

      assert_response :success
      assert_select 'div.project-content', text: /Lore impsuum/
    end
  end

  def test_do_not_show_overview_content_box
    with_additionals_settings(project_overview_content: '') do
      @request.session[:user_id] = 4
      get :show,
          params: { id: 1 }

      assert_response :success
      assert_select 'div.project-content', count: 0
    end
  end
end
