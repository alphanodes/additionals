# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DashboardsControllerTest < Additionals::ControllerTest
  include CrudControllerBase

  def setup
    prepare_tests

    User.current = nil
    @user = users :users_002
    @user_without_permission = users :users_004

    @crud = { form: :dashboard,
              show_assert_response: 406,
              index_assert_response: 406,
              create_params: { name: 'tester board',
                               enable_sidebar: true,
                               dashboard_type: DashboardContentWelcome::TYPE_NAME,
                               author_id: @user.id },
              create_assert_equals: { name: 'tester board' },
              create_assert: %i[enable_sidebar],
              edit_assert_select: ['form#dashboard-form'],
              update_params: { name: 'changed',
                               enable_sidebar: true },
              update_assert_equals: { name: 'changed' },
              update_assert: %i[enable_sidebar],
              entity: dashboards(:private_welcome2),
              delete_redirect_to: home_url }
  end

  def test_unlock_welcome_system_dashboard
    @request.session[:user_id] = 1

    dashboard = dashboards :system_default_welcome

    put :update,
        params: { id: dashboard.id,
                  dashboard: { locked: false } }

    assert_response :redirect

    dashboard.reload

    assert_not dashboard.locked
  end

  def test_unlock_project_system_dashboard
    @request.session[:user_id] = 1

    dashboard = dashboards :system_default_project

    put :update,
        params: { id: dashboard.id,
                  dashboard: { locked: false,
                               content_project_id: 1 } }

    assert_response :redirect

    dashboard.reload

    assert_not dashboard.locked
  end

  def test_update_project_system_dashboard_with_project_should_not_possible
    @request.session[:user_id] = 1

    dashboard = dashboards :system_default_project

    assert_raises Dashboard::ProjectSystemDefaultChangeException do
      put :update,
          params: { id: dashboard.id,
                    dashboard: { locked: false,
                                 project_id: 1,
                                 content_project_id: 1 } }
    end
  end
end
