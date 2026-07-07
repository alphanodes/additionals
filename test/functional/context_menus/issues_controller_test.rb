# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

module ContextMenus
  class IssuesControllerTest < Additionals::ControllerTest
    def setup
      User.current = nil
      @request.session[:user_id] = 2
    end

    # Regression: the additionals ViewHook renders a partial into the issues
    # context menu. Redmine 7 namespaced the controller to
    # ContextMenus::IssuesController, so a bare partial name no longer resolves
    # against app/views/context_menus/. The hook must reference the full path,
    # otherwise the whole menu 404s with ActionView::MissingTemplate.
    def test_index_renders_with_additionals_context_menu_hook
      get :index, params: { ids: [1], back_url: '/issues' }

      assert_response :success
      assert_select 'a.icon-edit'
    end

    # Proves the hook partial actually executes (not just resolves): with the
    # setting on it freezes the menu for a closed issue the user may not reopen,
    # turning the edit link into a disabled placeholder (href '#').
    def test_freezes_closed_issue_menu_when_setting_enabled
      get :index, params: { ids: [8], back_url: '/issues' }

      assert_response :success
      assert_select 'a.icon-edit[href=?]', '/issues/8/edit'

      with_plugin_settings 'additionals', issue_freezed_with_close: true do
        get :index, params: { ids: [8], back_url: '/issues' }

        assert_response :success
        assert_select 'a.icon-edit[href=?]', '/issues/8/edit', count: 0
        assert_select 'a.icon-edit.disabled'
      end
    end
  end
end
