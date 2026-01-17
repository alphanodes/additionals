# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class ViewContactsFormDetailsBottomRenderOn < Redmine::Hook::ViewListener
  render_on :view_contacts_form_details_bottom, inline: '<div class="test-contacts-form">Hook content</div>'
end

class ContactsControllerTest < Additionals::ControllerTest
  def setup
    skip 'Skip test, because redmine_servicedesk is not installed' unless AdditionalsPlugin.active_servicedesk?
    prepare_tests

    # Enable contacts module for project 1
    project = Project.find 1
    project.enable_module! :contacts

    # Add contacts permissions to Manager role
    manager_role = Role.find 1
    manager_role.add_permission! :view_contacts
    manager_role.add_permission! :add_contacts
    manager_role.add_permission! :edit_contacts
  end

  def test_new_with_hook_view_contacts_form_details_bottom
    Redmine::Hook.add_listener ViewContactsFormDetailsBottomRenderOn
    @request.session[:user_id] = 2

    get :new,
        params: { project_id: 1 }

    assert_response :success
    assert_select 'div.test-contacts-form', text: 'Hook content'
  end

  def test_edit_with_hook_view_contacts_form_details_bottom
    Redmine::Hook.add_listener ViewContactsFormDetailsBottomRenderOn
    @request.session[:user_id] = 2

    contact = contacts :adam
    skip 'No contacts available for edit test' if contact.nil?

    get :edit,
        params: { id: contact.id }

    assert_response :success
    assert_select 'div.test-contacts-form', text: 'Hook content'
  end
end
