# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Blocks with declared settings next to blocks without declarations. Dashboard
# constantizes the content class from the dashboard_type, so it lives at the
# top level and its name follows TYPE_NAME.
class DashboardContentSettingsStub < DashboardContent
  TYPE_NAME = 'SettingsStubDashboard'

  DECLARED_BLOCK = Class.new DashboardBlocks::Base do
    block_id 'declared'
    label { 'Declared' }
    max_occurs 2
    settings_filter ->(settings, _dashboard) { settings.except :secret }
    setting :title, **DashboardContent::TITLE_SETTING
    setting :secret, type: :string
    setting :max_entries, **DashboardContent::MAX_ENTRIES_SETTING
  end

  FIXED_BLOCK = Class.new DashboardBlocks::Base do
    block_id 'fixed'
    label { 'Fixed' }
    no_settings!
  end

  # A block with an own settings form that declares nothing keeps every setting
  OWN_QUERY_LIST_BLOCK = Class.new DashboardBlocks::Base do
    block_id 'own_query_list'
    label { 'Own query list' }
    settings_partial 'dashboards/blocks/own_settings'
  end

  def blocks
    super.merge 'declared' => DECLARED_BLOCK.new(self),
                'fixed' => FIXED_BLOCK.new(self),
                'own_query_list' => OWN_QUERY_LIST_BLOCK.new(self)
  end
end

class DashboardBlockSettingsTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
    @dashboard = Dashboard.new name: 'Settings', dashboard_type: DashboardContentSettingsStub::TYPE_NAME, author_id: 1
  end

  def test_unknown_settings_are_dropped
    @dashboard.update_block_settings 'feed', url: 'https://example.org/feed', chart: 'pie'

    assert_equal({ url: 'https://example.org/feed' }, @dashboard.layout_settings('feed'))
  end

  def test_valid_settings_report_no_errors
    assert_empty @dashboard.update_block_settings('feed', url: 'https://example.org/feed')
  end

  def test_invalid_setting_is_reported
    errors = @dashboard.update_block_settings 'feed', url: 'https://example.org/feed', max_entries: '500'

    assert_equal [:max_entries], errors.keys
  end

  def test_invalid_setting_keeps_the_stored_settings
    @dashboard.update_block_settings 'feed', url: 'https://example.org/feed'
    @dashboard.update_block_settings 'feed', url: 'https://example.org/other', max_entries: '500'

    assert_equal({ url: 'https://example.org/feed' }, @dashboard.layout_settings('feed'))
  end

  def test_stored_settings_count_for_required_settings
    @dashboard.update_block_settings 'feed', url: 'https://example.org/feed'

    assert_empty @dashboard.update_block_settings('feed', max_entries: '5')
  end

  def test_settings_are_stored_as_forms_send_them
    @dashboard.update_block_settings 'news', max_entries: 5

    assert_equal({ max_entries: '5' }, @dashboard.layout_settings('news'))
  end

  def test_settings_filter_runs_before_the_schema
    @dashboard.update_block_settings 'declared', title: 'Mine', secret: 'x'

    assert_equal({ title: 'Mine' }, @dashboard.layout_settings('declared'))
  end

  def test_numbered_block_uses_the_settings_of_its_definition
    @dashboard.update_block_settings 'declared__2', title: 'Mine', chart: 'pie'

    assert_equal({ title: 'Mine' }, @dashboard.layout_settings('declared__2'))
  end

  def test_block_without_settings_drops_all_settings
    @dashboard.update_block_settings 'fixed', title: 'Mine'

    assert_empty @dashboard.layout_settings('fixed')
  end

  def test_block_without_declared_settings_keeps_all_settings
    @dashboard.update_block_settings 'own_query_list', query_id: '1', secret: 'x'

    assert_equal({ query_id: '1', secret: 'x' }, @dashboard.layout_settings('own_query_list'))
  end

  def test_query_list_block_offers_visible_queries_of_its_class
    values = schema_values 'issuequery', :query_id

    assert_includes values, queries(:queries_004).id.to_s
  end

  def test_query_list_block_does_not_offer_queries_of_another_class
    values = schema_values 'issuequery', :query_id

    assert_not_includes values, queries(:queries_010).id.to_s
  end

  def test_query_list_block_rejects_an_unknown_query
    errors = @dashboard.update_block_settings 'issuequery', query_id: '999999'

    assert_equal [:query_id], errors.keys
  end

  def test_query_list_block_offers_the_columns_of_its_query
    values = schema_values 'issuequery', :columns, query_id: queries(:queries_004).id

    assert_includes values, 'subject'
  end

  def test_query_list_block_rejects_an_unknown_column
    errors = @dashboard.update_block_settings 'issuequery', query_id: queries(:queries_004).id.to_s,
                                                            columns: %w[subject secret]

    assert_equal [:columns], errors.keys
  end

  # The errors do not tell whether a private query of another user exists
  def test_query_list_block_checks_no_columns_of_a_query_the_user_cannot_see
    User.current = users :users_002
    [queries(:queries_003).id, 999_999].each do |query_id|
      errors = @dashboard.update_block_settings 'issuequery', query_id: query_id.to_s, columns: %w[secret]

      assert_equal [:query_id], errors.keys, query_id
    end
  end

  def test_stored_query_the_editor_cannot_see_keeps_the_block_editable
    @dashboard.layout_settings['issuequery'] = { query_id: '999999' }

    assert_empty @dashboard.update_block_settings('issuequery', max_entries: '5')
  end

  def test_query_list_block_accepts_a_column_its_form_offers_on_another_project
    field = IssueCustomField.create! name: 'Elsewhere', field_format: 'string', is_for_all: false
    content = DashboardContentSettingsStub.new project: projects(:projects_001)
    schema = content.block_settings 'issuequery', values: { query_id: queries(:queries_004).id.to_s, columns: ["cf_#{field.id}"] }

    assert_predicate schema, :valid?
  end

  def test_block_without_declared_settings_has_no_schema
    assert_nil @dashboard.content.block_settings('own_query_list')
  end

  def test_available_block_schemas_describe_the_settings
    schemas = @dashboard.content.available_block_schemas dashboard: @dashboard

    assert_equal %i[title url max_entries], schemas['feed'][:settings].pluck(:key)
  end

  def test_available_block_schemas_name_max_occurs
    assert_equal 2, @dashboard.content.available_block_schemas['declared'][:max_occurs]
  end

  def test_available_block_schemas_respect_permissions
    Role.non_member.remove_permission! :view_issues
    User.current = User.generate!
    content = DashboardContentSettingsStub.new

    assert_not_includes content.available_block_schemas.keys, 'issuequery'
  end

  def test_news_offers_subprojects_on_a_project_only
    content = DashboardContentSettingsStub.new project: projects(:projects_001)

    assert_includes content.block_settings('news').describe.pluck(:key), :with_subprojects
  end

  def test_news_offers_no_subprojects_without_a_project
    assert_not_includes @dashboard.content.block_settings('news').describe.pluck(:key), :with_subprojects
  end

  private

  def schema_values(block, key, values = {})
    description = @dashboard.content.block_settings(block, values:).describe
    description.detect { |setting| setting[:key] == key }[:values].pluck :value
  end
end
