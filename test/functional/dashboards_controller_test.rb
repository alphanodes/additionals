# frozen_string_literal: true

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
end
