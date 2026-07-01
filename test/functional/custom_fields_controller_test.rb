# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Verifies the Deface override on custom_fields/formats/_user that adds the
# user scope selector (all / active / project / roles) to the "user" format.
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
end
