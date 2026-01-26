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

  def test_new_with_copy_param_should_copy_dashboard
    @request.session[:user_id] = @user.id

    source = dashboards :private_welcome2
    source.update! description: 'Source description',
                   enable_sidebar: true

    get :new, params: { copy: source.id }

    assert_response :success
    assert_select 'form#dashboard-form' do
      # Name input should exist but we don't check for empty value (no value attribute when empty)
      assert_select 'input[name="dashboard[name]"]'
      # Description should be copied
      assert_select 'textarea[name="dashboard[description]"]', text: source.description
      # enable_sidebar should be copied (checked)
      assert_select 'input[name="dashboard[enable_sidebar]"][type="checkbox"][checked="checked"]'
      # dashboard_type should be set
      assert_select "input[name='dashboard[dashboard_type]'][value='#{source.dashboard_type}']"
    end
  end

  def test_new_with_copy_param_for_project_dashboard_should_copy
    @request.session[:user_id] = @user.id

    source = dashboards :private_project2
    source.update! description: 'Project dashboard description'

    get :new, params: { project_id: source.project_id, copy: source.id }

    assert_response :success
    assert_select 'form#dashboard-form' do
      # Description should be copied
      assert_select 'textarea[name="dashboard[description]"]', text: source.description
    end
  end

  def test_new_with_invalid_copy_param_should_render_empty_form
    @request.session[:user_id] = @user.id

    get :new, params: { copy: 99_999 }

    assert_response :success
    assert_select 'form#dashboard-form' do
      # Description should be empty
      assert_select 'textarea[name="dashboard[description]"]', text: ''
    end
  end

  def test_new_with_copy_param_should_not_copy_invisible_dashboard
    # SECURITY TEST: User must not be able to copy dashboards they cannot see
    # Dashboard blocks may contain sensitive data (credentials, API keys)
    other_user = users :users_003
    @request.session[:user_id] = other_user.id

    # private_welcome is a private dashboard owned by user 1, invisible to user 3
    source = dashboards :private_welcome
    source.update! description: 'Contains sensitive block settings'

    get :new, params: { copy: source.id }

    assert_response :success
    assert_select 'form#dashboard-form' do
      # Dashboard should NOT have copied the private dashboard's description
      assert_select 'textarea[name="dashboard[description]"]', text: ''
    end
  end

  def test_create_from_copy_should_create_new_dashboard
    @request.session[:user_id] = @user.id

    source = dashboards :private_welcome2
    source.update! description: 'Original description',
                   enable_sidebar: true,
                   layout: { left: %w[welcome], right: %w[news] }

    assert_difference 'Dashboard.count', 1 do
      post :create, params: {
        dashboard: {
          name: 'Copied Dashboard',
          dashboard_type: source.dashboard_type,
          description: source.description,
          enable_sidebar: source.enable_sidebar
        }
      }
    end

    assert_response :redirect

    new_dashboard = Dashboard.last

    assert_equal 'Copied Dashboard', new_dashboard.name
    assert_equal source.description, new_dashboard.description
    assert_equal source.enable_sidebar, new_dashboard.enable_sidebar
    assert_equal @user.id, new_dashboard.author_id
  end

  def test_create_from_copy_should_copy_layout_blocks
    @request.session[:user_id] = @user.id

    source = dashboards :private_welcome2
    source.update! layout: { 'left' => %w[welcome], 'right' => %w[news], 'top' => %w[activity] },
                   layout_settings: { 'activity' => { max_entries: '15' } }

    assert_difference 'Dashboard.count', 1 do
      post :create, params: {
        copy: source.id,
        dashboard: {
          name: 'Dashboard with copied blocks',
          dashboard_type: source.dashboard_type
        }
      }
    end

    assert_response :redirect

    new_dashboard = Dashboard.last

    assert_equal source.layout, new_dashboard.layout
    assert_equal source.layout_settings, new_dashboard.layout_settings
    assert_includes new_dashboard.layout['top'], 'activity'
    assert_equal '15', new_dashboard.layout_settings['activity'][:max_entries]
  end

  def test_new_with_copy_param_should_not_copy_non_editable_dashboard
    # SECURITY TEST: User must have EDIT permission to copy a dashboard
    # visible? is not enough - editable? is required because block settings may contain credentials
    @request.session[:user_id] = @user.id

    # system_default_welcome is PUBLIC (visibility: 2) and owned by user 1
    # @user (user 2) can SEE it but cannot EDIT it (not author, not admin)
    source = dashboards :system_default_welcome
    source.update! description: 'Contains sensitive API keys in block settings'

    assert source.visible?(@user), 'Dashboard should be visible to user'
    assert_not source.editable?(@user), 'Dashboard should NOT be editable by user'

    get :new, params: { copy: source.id }

    assert_response :success
    assert_select 'form#dashboard-form' do
      # Dashboard should NOT have copied the non-editable dashboard's data
      assert_select 'textarea[name="dashboard[description]"]', text: ''
    end
  end

  def test_create_from_copy_should_not_copy_layout_from_non_editable_dashboard
    # SECURITY TEST: Blocks should not be copied from non-editable dashboards
    @request.session[:user_id] = @user.id

    # system_default_welcome is PUBLIC but owned by user 1, not editable by @user
    source = dashboards :system_default_welcome

    assert source.visible?(@user), 'Dashboard should be visible'
    assert_not source.editable?(@user), 'Dashboard should NOT be editable'

    original_layout = source.layout.deep_dup

    assert_difference 'Dashboard.count', 1 do
      post :create, params: {
        copy: source.id,
        dashboard: {
          name: 'Attempted copy of non-editable dashboard',
          dashboard_type: DashboardContentWelcome::TYPE_NAME
        }
      }
    end

    new_dashboard = Dashboard.last

    # Layout should NOT be copied from the non-editable source
    assert_not_equal original_layout, new_dashboard.layout
  end

  def test_lock_action_registered_in_save_dashboards_permission
    # IMPORTANT: lock action must be registered in save_dashboards permission
    # Without this, the action is not properly documented in Redmine's permission system
    permission = Redmine::AccessControl.permission :save_dashboards

    assert_not_nil permission, 'save_dashboards permission should exist'
    assert_includes permission.actions, 'dashboards/lock',
                    'lock action must be registered in save_dashboards permission'
  end

  def test_unlock_action_registered_in_save_dashboards_permission
    # IMPORTANT: unlock action must be registered in save_dashboards permission
    permission = Redmine::AccessControl.permission :save_dashboards

    assert_not_nil permission, 'save_dashboards permission should exist'
    assert_includes permission.actions, 'dashboards/unlock',
                    'unlock action must be registered in save_dashboards permission'
  end

  def test_lock_action_registered_in_share_dashboards_permission
    # IMPORTANT: lock action must be registered in share_dashboards permission
    permission = Redmine::AccessControl.permission :share_dashboards

    assert_not_nil permission, 'share_dashboards permission should exist'
    assert_includes permission.actions, 'dashboards/lock',
                    'lock action must be registered in share_dashboards permission'
  end

  def test_unlock_action_registered_in_share_dashboards_permission
    # IMPORTANT: unlock action must be registered in share_dashboards permission
    permission = Redmine::AccessControl.permission :share_dashboards

    assert_not_nil permission, 'share_dashboards permission should exist'
    assert_includes permission.actions, 'dashboards/unlock',
                    'unlock action must be registered in share_dashboards permission'
  end

  def test_lock_dashboard_as_author
    # User 2 is author of private_welcome2 and has save_dashboards permission
    @request.session[:user_id] = @user.id

    dashboard = dashboards :private_welcome2

    assert_equal @user.id, dashboard.author_id, 'Test user should be the dashboard author'
    assert_not @user.admin?, 'Test user should not be admin'
    assert_not dashboard.locked?, 'Dashboard should not be locked initially'

    put :lock, params: { id: dashboard.id }

    assert_response :redirect
    dashboard.reload

    assert dashboard.locked?, 'Dashboard should be locked after lock action'
  end

  def test_lock_dashboard_as_non_author
    # User 4 is not author and not admin - should be forbidden
    @request.session[:user_id] = @user_without_permission.id

    dashboard = dashboards :private_welcome2

    assert_not_equal @user_without_permission.id, dashboard.author_id, 'Test user should not be the author'
    assert_not @user_without_permission.admin?, 'Test user should not be admin'

    put :lock, params: { id: dashboard.id }

    assert_response :forbidden
    dashboard.reload

    assert_not dashboard.locked?, 'Dashboard should remain unlocked'
  end

  def test_unlock_dashboard_as_author
    @request.session[:user_id] = @user.id

    dashboard = dashboards :private_welcome2
    dashboard.update! locked: true

    assert_equal @user.id, dashboard.author_id, 'Test user should be the dashboard author'
    assert_not @user.admin?, 'Test user should not be admin'
    assert dashboard.locked?, 'Dashboard should be locked initially'

    put :unlock, params: { id: dashboard.id }

    assert_response :redirect
    dashboard.reload

    assert_not dashboard.locked?, 'Dashboard should be unlocked after unlock action'
  end

  def test_unlock_dashboard_as_non_author
    @request.session[:user_id] = @user_without_permission.id

    dashboard = dashboards :private_welcome2
    dashboard.update! locked: true

    assert_not_equal @user_without_permission.id, dashboard.author_id, 'Test user should not be the author'
    assert_not @user_without_permission.admin?, 'Test user should not be admin'

    put :unlock, params: { id: dashboard.id }

    assert_response :forbidden
    dashboard.reload

    assert dashboard.locked?, 'Dashboard should remain locked'
  end

  def test_lock_project_dashboard_as_author
    @request.session[:user_id] = @user.id

    dashboard = dashboards :private_project2

    assert_equal @user.id, dashboard.author_id, 'Test user should be the dashboard author'
    assert_not @user.admin?, 'Test user should not be admin'
    assert_not dashboard.locked?, 'Dashboard should not be locked initially'

    put :lock, params: { project_id: dashboard.project_id, id: dashboard.id }

    assert_response :redirect
    dashboard.reload

    assert dashboard.locked?, 'Dashboard should be locked after lock action'
  end

  def test_unlock_project_dashboard_as_author
    @request.session[:user_id] = @user.id

    dashboard = dashboards :private_project2
    dashboard.update! locked: true

    assert_equal @user.id, dashboard.author_id, 'Test user should be the dashboard author'
    assert_not @user.admin?, 'Test user should not be admin'

    put :unlock, params: { project_id: dashboard.project_id, id: dashboard.id }

    assert_response :redirect
    dashboard.reload

    assert_not dashboard.locked?, 'Dashboard should be unlocked after unlock action'
  end
end
