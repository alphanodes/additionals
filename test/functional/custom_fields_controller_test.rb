# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Verifies the additionals form partial of the "user" format that adds the
# user scope selector (all / active / project / roles).
class CustomFieldsControllerTest < Additionals::ControllerTest
  def setup
    @request.session[:user_id] = 1
  end

  def test_edit_user_format_field_renders_scope_selector
    field = IssueCustomField.create! name: 'Owner', field_format: 'user', user_scope: '1'

    get :edit, params: { id: field.id }

    assert_response :success
    # count: 1 guards against duplicated rendering (regression: a Deface
    # nth-of-type override matched both <p> and rendered the block twice).
    %w[1 4 2 3].each do |value|
      assert_select 'input[type=radio][name=?][value=?]', 'custom_field[user_scope]', value, count: 1
    end
  end

  def test_edit_user_format_field_preselects_stored_scope
    field = IssueCustomField.create! name: 'Owner', field_format: 'user', user_scope: '4'

    get :edit, params: { id: field.id }

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
