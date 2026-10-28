# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Verifies the additionals form partials: the "user" format with its user
# scope selector (all / active / project / roles) and the number list.
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

  # The number list offers its values, a default and the display style, but no
  # multiple values, no links and no search
  def test_edit_number_list_field_renders_its_own_options
    field = IssueCustomField.create! name: 'Size', field_format: 'number_list', possible_values: %w[1 2 3]

    get :edit, params: { id: field.id }

    assert_response :success
    assert_select 'textarea[name=?]', 'custom_field[possible_values]', text: "1\n2\n3"
    assert_select 'input[name=?]', 'custom_field[default_value]'
    assert_select 'select[name=?]', 'custom_field[edit_tag_style]'
    %w[value_prefix_icon value_suffix_icon].each do |attribute|
      assert_select 'select[name=?]', "custom_field[#{attribute}]"
    end
    %w[multiple url_pattern searchable].each do |attribute|
      assert_select 'input[name=?]', "custom_field[#{attribute}]", 0
    end
  end

  def test_update_number_list_field_saves_prefix_and_suffix
    field = IssueCustomField.create! name: 'Size', field_format: 'number_list', possible_values: %w[1 2 3]

    put :update, params: { id: field.id, custom_field: { value_prefix: '$', value_prefix_icon: 'star',
                                                         value_suffix: 'kg', value_suffix_icon: 'coins' } }

    field.reload

    assert_equal ['$', 'star', 'kg', 'coins'],
                 [field.value_prefix, field.value_prefix_icon, field.value_suffix, field.value_suffix_icon]
  end
end
