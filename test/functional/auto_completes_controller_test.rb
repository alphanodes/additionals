# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AutoCompletesControllerTest < Additionals::ControllerTest
  include Redmine::I18n

  def setup
    prepare_tests
    Setting.default_language = 'en'
    # Frontend callers (select2, jQuery autocomplete) ask for JSON, so do the tests.
    @request.headers['Accept'] = 'application/json'
  end

  def test_issue_assignee
    with_settings issue_group_assignment: '0' do
      get :issue_assignee, xhr: true

      assert_response :success
      json = ActiveSupport::JSON.decode response.body

      assert_kind_of Array, json
      assert_equal 2, json.count

      assert_equal 'me', json.first['id']
      assert_equal 'active', json.second['text']
      assert_equal 4, json.second['children'].count
    end
  end

  # Form selects write to an assigned_to_id column, where the filter default 'me' would cast
  # to integer 0 and violate the foreign key. They pass the real user id via me_value instead.
  def test_issue_assignee_with_me_value_replaces_me_id
    @request.session[:user_id] = 2

    get :issue_assignee,
        params: { me_value: 2 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_equal '2', json.first['id']
    assert_equal '2', json.first['value']
  end

  def test_issue_assignee_with_groups_enabled
    with_settings issue_group_assignment: '1' do
      get :issue_assignee, xhr: true

      assert_response :success
      json = ActiveSupport::JSON.decode response.body

      assert_kind_of Array, json

      group_section = json.detect { |g| g.is_a?(Hash) && g['text'] == 'Groups' }

      assert_not_nil group_section, 'Expected Groups section when issue_group_assignment is enabled'
      assert group_section['children'].any?, 'Expected at least one group'
    end
  end

  def test_issue_assignee_with_involved_principals
    issue = issues :issues_001

    get :issue_assignee,
        params: { project_id: 1, issue_id: issue.id },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json

    involved_group = json.detect { |g| g.is_a?(Hash) && g['children'] && g['text'] != 'active' }

    assert_not_nil involved_group, 'Expected involved principals group'
    assert involved_group['children'].any?
  end

  def test_issue_assignee_disables_involved_principals_who_cannot_be_assigned
    issue = issues :issues_001
    note_author = users :users_007
    Journal.create! journalized: issue, user: note_author, notes: 'Latest note'

    get :issue_assignee,
        params: { project_id: 1, issue_id: issue.id },
        xhr: true

    assert(involved_principals(response.body).detect { |entry| entry['id'] == note_author.id }['disabled'])
  end

  def test_issue_assignee_offers_no_involved_principals_of_an_invisible_issue
    get :issue_assignee,
        params: { project_id: 1, issue_id: issues(:issues_006).id },
        xhr: true

    assert_empty involved_principals(response.body)
  end

  def test_assignee
    get :assignee, xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 3, json.count

    assert_equal 'me', json.first['id']
    assert_equal 'active', json.second['text']
    assert_equal 7, json.second['children'].count
    assert_equal 'Groups', json.third['text']
    assert_equal 2, json.third['children'].count
  end

  def test_assignee_with_groups_then_users_format
    with_settings assignee_dropdown_display_format: 'groups_then_users' do
      get :assignee, xhr: true

      assert_response :success
      json = ActiveSupport::JSON.decode response.body

      assert_equal 'me', json.first['id']
      assert_equal 'Groups', json.second['text']
      assert_equal 2, json.second['children'].count
      assert_equal 'active', json.third['text']
      assert_equal 7, json.third['children'].count
    end
  end

  def test_assignee_with_users_by_group_format
    with_settings assignee_dropdown_display_format: 'users_by_group' do
      get :assignee, xhr: true

      assert_response :success
      json = ActiveSupport::JSON.decode response.body

      assert_equal 'me', json.first['id']
      assert_equal 'Groups', json.second['text']

      a_team = json.detect { |g| g.is_a?(Hash) && g['text'] == Group.find(10).name }

      assert_not_nil a_team, 'Expected a per-group section listing the group members'
      assert_equal [8], a_team['children'].pluck('id')
    end
  end

  def test_grouped_principals_ignores_assignee_format_without_flag
    with_settings assignee_dropdown_display_format: 'groups_then_users' do
      get :grouped_principals, xhr: true

      assert_response :success
      json = ActiveSupport::JSON.decode response.body

      # Without the assignee_format flag the legacy order is kept (active before Groups),
      # even though the setting requests groups first.
      assert_equal 'active', json.first['text']
      assert_equal 'Groups', json.second['text']
    end
  end

  def test_grouped_principals_applies_assignee_format_with_flag
    with_settings assignee_dropdown_display_format: 'groups_then_users' do
      get :grouped_principals,
          params: { assignee_format: true },
          xhr: true

      assert_response :success
      json = ActiveSupport::JSON.decode response.body

      assert_equal 'Groups', json.first['text']
      assert_equal 'active', json.second['text']
    end
  end

  def test_grouped_principals_keeps_group_names_as_plain_json_text
    group = Group.find 10
    group.update_column :lastname, %q(Team "A" \\ <b>O'Brien</b>)

    with_settings assignee_dropdown_display_format: 'users_by_group' do
      get :grouped_principals,
          params: { assignee_format: true },
          xhr: true

      assert_response :success
      json = ActiveSupport::JSON.decode response.body

      assert_includes json.pluck('text'), group.lastname
    end
  end

  def test_grouped_principals
    get :grouped_principals, xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 2, json.count

    assert_equal 'active', json.first['text']
    assert_equal 7, json.first['children'].count
    assert_equal 'Groups', json.second['text']
    assert_equal 2, json.second['children'].count
  end

  def test_grouped_principals_with_me
    get :grouped_principals,
        params: { with_me: true },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json

    assert_equal 3, json.count
    assert_equal 'me', json.first['id']
    assert_equal 'active', json.second['text']
    assert_equal 7, json.second['children'].count
    assert_equal 'Groups', json.third['text']
    assert_equal 2, json.third['children'].count
  end

  def test_grouped_principals_with_me_value_replaces_me_id
    @request.session[:user_id] = 2

    get :grouped_principals,
        params: { with_me: true, me_value: 2 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_equal '2', json.first['id']
    assert_equal '2', json.first['value']
  end

  def test_grouped_users
    get :grouped_users, xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    assert_equal 'active', json.first['text']
    assert_equal 7, json.first['children'].count
  end

  def test_grouped_users_should_respond_to_accept_json
    get :grouped_users, xhr: true

    assert_response :success
    assert_equal 'application/json', response.media_type
  end

  def test_grouped_principals_should_respond_to_accept_json
    get :grouped_principals, xhr: true

    assert_response :success
    assert_equal 'application/json', response.media_type
  end

  def test_grouped_users_with_me
    get :grouped_users,
        params: { with_me: true },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 2, json.count

    assert_equal 'me', json.first['id']
    assert_equal 'active', json.second['text']
    assert_equal 7, json.second['children'].count
  end

  def test_grouped_users_with_ano
    get :grouped_users,
        params: { with_ano: true },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 2, json.count

    assert_equal 'active', json.first['text']
    assert_equal 7, json.first['children'].count
    assert_equal 'Anonymous', json.second['text']
  end

  def test_grouped_users_for_project
    get :grouped_users,
        params: { project_id: 1 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    assert_equal 'active', json.first['text']
    assert_equal 2, json.first['children'].count
  end

  def test_grouped_users_with_excluded_user
    get :grouped_users,
        params: { user_id: 2 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    assert_equal 'active', json.first['text']
    assert_equal 6, json.first['children'].count
    assert_not(json.first['children'].detect { |u| u['id'] == 2 })
  end

  def test_grouped_users_with_search
    get :grouped_users,
        params: { q: 'john' },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    children = json.first['children']

    assert_equal 1, children.count

    entry = children.first

    assert_equal 2, entry['id']
    assert_equal 'John Smith', entry['text']
    assert_equal 'John Smith', entry['name']
    assert_equal 2, entry['value']
  end

  def test_authors
    get :authors, xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 'me', json.first['id']
    assert_equal 'active', json.second['text']
  end

  def test_authors_for_project
    get :authors,
        params: { project_id: 1 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 'me', json.first['id']
    assert json.second['children'].any?
  end

  def test_authors_with_search
    get :authors,
        params: { q: 'john' },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    children = json.first['children']

    assert_equal 1, children.count
    assert_equal 2, children.first['id']
    assert_equal 'John Smith', children.first['text']
  end

  def test_custom_field_users_without_project
    get :custom_field_users,
        params: { custom_field_id: 1 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_empty json
  end

  def test_custom_field_users_for_project
    cf = IssueCustomField.create! name: 'Test User CF',
                                  field_format: 'user',
                                  is_for_all: true,
                                  tracker_ids: [1]

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert json.any?
  end

  def test_custom_field_users_defaults_to_me_id
    cf = IssueCustomField.create! name: 'Test User CF',
                                  field_format: 'user',
                                  is_for_all: true,
                                  tracker_ids: [1]

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_equal 'me', json.first['id']
  end

  def test_custom_field_users_with_me_value_replaces_me_id
    @request.session[:user_id] = 2
    cf = IssueCustomField.create! name: 'Test User CF',
                                  field_format: 'user',
                                  is_for_all: true,
                                  tracker_ids: [1]

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id, me_value: 2 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_equal '2', json.first['id']
    assert_equal '2', json.first['value']
  end

  def test_custom_field_users_with_search
    cf = IssueCustomField.create! name: 'Test User CF',
                                  field_format: 'user',
                                  is_for_all: true,
                                  tracker_ids: [1]

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id, q: 'john' },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    children = json.first['children']

    assert_equal 1, children.count
    assert_equal 'John Smith', children.first['text']
  end

  def test_custom_field_users_with_invalid_cf
    get :custom_field_users,
        params: { project_id: 1, custom_field_id: 99_999 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_empty json
  end

  def test_authors_requires_login
    with_settings login_required: '1' do
      @request.session[:user_id] = nil
      get :authors, xhr: true

      assert_response :forbidden
    end
  end

  def test_authors_scoped_by_visibility
    @request.session[:user_id] = 8

    get :authors,
        params: { project_id: 1 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    # Results are scoped by user visibility, not full project member list
    assert_kind_of Array, json
  end

  def test_custom_field_users_requires_login
    with_settings login_required: '1' do
      @request.session[:user_id] = nil
      get :custom_field_users,
          params: { project_id: 1, custom_field_id: 1 },
          xhr: true

      assert_response :forbidden
    end
  end

  def test_custom_field_users_scoped_by_visibility
    @request.session[:user_id] = 8

    cf = IssueCustomField.create! name: 'Test User CF Perm',
                                  field_format: 'user',
                                  is_for_all: true,
                                  tracker_ids: [1]

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
  end

  def test_issue_assignee_requires_login
    with_settings login_required: '1' do
      @request.session[:user_id] = nil
      get :issue_assignee, xhr: true

      assert_response :forbidden
    end
  end

  def test_grouped_users_scope
    Role.anonymous.update! users_visibility: 'members_of_visible_projects'
    @request.session[:user_id] = nil
    get :grouped_users, xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    assert_equal 'active', json.first['text']
    assert_equal 2, json.first['children'].count
  end

  def test_custom_field_users_scope_all_includes_active_non_project_user
    @request.session[:user_id] = 1
    outsider = User.generate! firstname: 'Xavier', lastname: 'Scopeoutsider'
    cf = IssueCustomField.create! name: 'Scope All CF', field_format: 'user', is_for_all: true, user_scope: '1'

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id, q: 'Scopeoutsider' },
        xhr: true

    assert_response :success
    assert_includes custom_field_users_ids(response.body), outsider.id
  end

  def test_custom_field_users_scope_all_includes_locked_user
    @request.session[:user_id] = 1
    locked = User.generate! firstname: 'Laura', lastname: 'Scopelocked', status: User::STATUS_LOCKED
    cf = IssueCustomField.create! name: 'Scope All Locked CF', field_format: 'user', is_for_all: true, user_scope: '1'

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id, q: 'Scopelocked' },
        xhr: true

    assert_response :success
    assert_includes custom_field_users_ids(response.body), locked.id
  end

  def test_custom_field_users_scope_active_includes_non_project_user
    @request.session[:user_id] = 1
    outsider = User.generate! firstname: 'Yara', lastname: 'Activeoutsider'
    cf = IssueCustomField.create! name: 'Scope Active CF', field_format: 'user', is_for_all: true, user_scope: '4'

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id, q: 'Activeoutsider' },
        xhr: true

    assert_response :success
    assert_includes custom_field_users_ids(response.body), outsider.id
  end

  def test_custom_field_users_scope_active_excludes_locked_user
    @request.session[:user_id] = 1
    locked = User.generate! firstname: 'Nora', lastname: 'Activelocked', status: User::STATUS_LOCKED
    cf = IssueCustomField.create! name: 'Scope Active Locked CF', field_format: 'user', is_for_all: true, user_scope: '4'

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id, q: 'Activelocked' },
        xhr: true

    assert_response :success
    assert_not_includes custom_field_users_ids(response.body), locked.id
  end

  def test_custom_field_users_without_me_for_multiple_values
    cf = IssueCustomField.create! name: 'Multiple User CF', field_format: 'user', is_for_all: true, multiple: true

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id },
        xhr: true

    assert_not_includes custom_field_users_raw_ids(response.body), 'me'
  end

  def test_custom_field_users_for_other_field_format
    get :custom_field_users,
        params: { project_id: 1, custom_field_id: custom_fields(:custom_fields_002).id },
        xhr: true

    assert_empty ActiveSupport::JSON.decode(response.body)
  end

  def test_custom_field_users_scope_all_offers_groups_if_the_field_allows_them
    skip 'Requires Redmine 7.1 or higher' unless CustomField.new.respond_to? :possible_principals

    @request.session[:user_id] = 1
    cf = IssueCustomField.create! name: 'Scope All Group CF', field_format: 'user', is_for_all: true,
                                  user_scope: '1', possible_principals: 'user_group'

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id, q: 'A Team' },
        xhr: true

    assert_includes custom_field_users_ids(response.body), 10
  end

  def test_custom_field_users_project_scope_offers_member_groups_if_the_field_allows_them
    skip 'Requires Redmine 7.1 or higher' unless CustomField.new.respond_to? :possible_principals

    @request.session[:user_id] = 1
    cf = IssueCustomField.create! name: 'Project Group CF', field_format: 'user', is_for_all: true,
                                  possible_principals: 'group'

    get :custom_field_users,
        params: { project_id: 2, custom_field_id: cf.id },
        xhr: true

    assert_equal [11], custom_field_users_ids(response.body)
  end

  def test_custom_field_users_start_list_offers_groups_beside_recent_users
    skip 'Requires Redmine 7.1 or higher' unless CustomField.new.respond_to? :possible_principals

    @request.session[:user_id] = 1
    cf = IssueCustomField.create! name: 'Start List Group CF', field_format: 'user', is_for_all: true,
                                  user_scope: '1', possible_principals: 'user_group'

    with_select2_init_entries 2 do
      get :custom_field_users,
          params: { project_id: 1, custom_field_id: cf.id },
          xhr: true
    end

    assert_includes custom_field_users_ids(response.body), 10
  end

  def test_grouped_principals_start_list_offers_groups_beside_recent_users
    @request.session[:user_id] = 1

    with_settings issue_group_assignment: '1' do
      with_select2_init_entries 1 do
        get :grouped_principals,
            params: { project_id: 2 },
            xhr: true
      end
    end

    assert_includes custom_field_users_ids(response.body), 11
  end

  private

  # Flattens the grouped select2 JSON payload into a plain list of user ids.
  def involved_principals(body)
    group = ActiveSupport::JSON.decode(body).detect { |entry| entry['text'] == l(:label_involved_principals) }
    group ? group['children'] : []
  end

  def custom_field_users_ids(body)
    custom_field_users_raw_ids(body).map(&:to_i)
  end

  def with_select2_init_entries(limit, &)
    AdditionalsConf.instance_variable_set :@select2_init_entries, nil
    Redmine::Configuration.with('select2_init_entries' => limit, &)
  ensure
    AdditionalsConf.instance_variable_set :@select2_init_entries, nil
  end

  def custom_field_users_raw_ids(body)
    json = ActiveSupport::JSON.decode body
    json.flat_map { |group| group['children'] || [group] }.filter_map { |entry| entry['id'] }
  end
end
