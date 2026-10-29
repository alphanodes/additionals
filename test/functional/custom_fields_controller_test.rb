# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Verifies the additionals form partial of the "user" format that adds the
# user scope selector (all / active / project / roles) for the entities a
# plugin registers, issue fields stand in for them here.
class CustomFieldsControllerTest < Additionals::ControllerTest
  def setup
    @request.session[:user_id] = 1
  end

  def test_create_user_format_field_saves_the_scope
    with_user_scope_for 'Issue' do
      post :create, params: { type: 'IssueCustomField',
                              custom_field: { name: 'Owner', field_format: 'user', user_scope: '4' } }
    end

    assert_equal '4', IssueCustomField.find_by(name: 'Owner').user_scope
  end

  def test_create_user_format_field_ignores_the_scope_for_unregistered_entities
    post :create, params: { type: 'TimeEntryCustomField',
                            custom_field: { name: 'Owner', field_format: 'user', user_scope: '4' } }

    assert_nil TimeEntryCustomField.find_by(name: 'Owner').user_scope
  end

  def test_edit_user_format_field_of_unregistered_entity_renders_the_core_form
    field = TimeEntryCustomField.create! name: 'Owner', field_format: 'user'

    get :edit, params: { id: field.id }

    assert_response :success
    assert_select 'input[name=?]', 'custom_field[user_scope]', count: 0
    assert_select 'input#custom_field_user_role_only[type=radio]'
  end

  def test_edit_user_format_field_renders_scope_selector
    field = IssueCustomField.create! name: 'Owner', field_format: 'user', user_scope: '1'

    with_user_scope_for('Issue') { get :edit, params: { id: field.id } }

    assert_response :success
    # count: 1 guards against duplicated rendering (regression: a Deface
    # nth-of-type override matched both <p> and rendered the block twice).
    %w[1 4 2 3].each do |value|
      assert_select 'input[type=radio][name=?][value=?]', 'custom_field[user_scope]', value, count: 1
    end
  end

  def test_edit_user_format_field_preselects_stored_scope
    field = IssueCustomField.create! name: 'Owner', field_format: 'user', user_scope: '4'

    with_user_scope_for('Issue') { get :edit, params: { id: field.id } }

    assert_response :success
    assert_select 'input[type=radio][name=?][value=?][checked=checked]', 'custom_field[user_scope]', '4'
  end

  def test_edit_user_format_field_renders_possible_principals_selector
    skip 'Requires Redmine 7.1 or higher' unless CustomField.new.respond_to? :possible_principals

    field = IssueCustomField.create! name: 'Owner', field_format: 'user', possible_principals: 'group'

    get :edit, params: { id: field.id }

    assert_select 'select#custom_field_possible_principals option[value=group][selected=selected]'
  end
end
