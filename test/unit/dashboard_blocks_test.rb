# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# A dashboard type of a plugin that still defines blocks the old way. Named
# with its TYPE_NAME: an anonymous class would stay among the descendants
# of DashboardContent and break DashboardContent.types.
class DashboardContentBlockDefinitionsStub < DashboardContent
  TYPE_NAME = 'BlockDefinitionsStubDashboard'

  def block_definitions = { 'foreign' => {} }
end

# Dashboard blocks as classes, collected from lib/dashboard_blocks of all plugins
class DashboardBlocksTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_002
  end

  def test_finds_a_block_by_its_id
    assert_equal DashboardBlocks::TextBlock, DashboardBlocks.find('text')
  end

  def test_base_classes_are_no_blocks
    assert_not_includes DashboardBlocks.all, DashboardBlocks::QueryListBlock
  end

  def test_block_of_one_dashboard_type_is_not_offered_on_another
    assert_not_includes DashboardBlocks.for(DashboardContentWelcome.new).map(&:class), DashboardBlocks::ProjectIssuesBlock
  end

  def test_block_without_dashboard_types_is_offered_on_every_content
    assert_includes DashboardBlocks.for(DashboardContent.new).map(&:class), DashboardBlocks::TextBlock
  end

  def test_every_block_has_an_id_and_a_label
    assert_empty(DashboardBlocks.all.reject { |block| block.block_id.present? && block.label.present? })
  end

  # A dashboard type is the name of a DashboardContent subclass, e.g. :welcome
  def test_blocks_name_existing_dashboard_types_only
    types = DashboardBlocks.all.flat_map { |block| block.declared_dashboard_types || [] }

    assert_empty(types.reject { |type| "DashboardContent#{type.to_s.camelize}".safe_constantize })
  end

  def test_content_offers_the_blocks_of_its_type
    block = DashboardContentProject.new(project: projects(:projects_001)).blocks['projectissues']

    assert_equal 'dashboards/blocks/project_issues', block.partial
  end

  def test_unavailable_block_is_not_offered
    content = DashboardContentProject.new project: projects(:projects_002)
    content.project.update_columns description: '', homepage: ''
    content.project.custom_values.delete_all

    assert_not content.available_blocks.key?('projectinformation')
  end

  def test_query_list_block_translates_the_label_of_its_query
    block = DashboardContentWelcome.new.blocks['issuequery']

    assert_equal I18n.t(:label_issue_plural), block.query_block[:label]
  end

  def test_contents_of_additionals_define_no_block_definitions
    assert_nil DashboardBlocks.check_patches!([DashboardContent, DashboardContentWelcome, DashboardContentProject])
  end

  def test_block_definitions_of_a_plugin_are_an_error
    assert_raises DashboardBlocks::PatchError do
      DashboardBlocks.check_patches! [DashboardContentBlockDefinitionsStub]
    end
  end

  def test_block_reads_a_stored_setting_typed
    block = DashboardContentWelcome.new.dashboard_block 'news', settings: { max_entries: '5' }

    assert_equal 5, block.max_entries
  end

  def test_block_reads_the_default_of_a_missing_setting
    assert_equal DashboardContent::DEFAULT_MAX_ENTRIES, DashboardContentWelcome.new.dashboard_block('news').max_entries
  end

  def test_block_reads_the_default_of_a_stored_number_out_of_bounds
    block = DashboardContentWelcome.new.dashboard_block 'my_spent_time', settings: { days: '0' }

    assert_equal 7, block.days
  end

  def test_block_of_an_unknown_id_is_nil
    assert_nil DashboardContentWelcome.new.dashboard_block('unknown')
  end

  def test_rule_of_a_setting_is_a_method_of_the_block
    block = DashboardContentProject.new(project: projects(:projects_001)).blocks['news']

    assert_equal :with_subprojects_available?, block.declared_settings[:with_subprojects][:if].name
  end

  def test_rule_of_a_setting_as_lambda_is_an_error
    assert_raises ArgumentError do
      Class.new(DashboardBlocks::Base) { setting :title, type: :string, applies: ->(_schema) { true } }
    end
  end

  def test_setting_must_not_replace_a_method_of_the_block
    assert_raises ArgumentError do
      Class.new(DashboardBlocks::Base) { setting :project, type: :string }
    end
  end

  def test_setting_named_like_a_method_gets_an_own_reader
    block = Class.new(DashboardBlocks::Base) { setting :project, type: :string, reader: :project_name }
    content = DashboardContentWelcome.new

    assert_equal 'Cookbook', block.new(content, settings: { project: 'Cookbook' }).project_name
  end

  def test_setting_named_like_a_rule_is_no_rule
    block = Class.new DashboardBlocks::Base do
      setting :threshold, type: :integer
      setting :threshold_default, type: :boolean, default: true
    end

    assert_not block.new(DashboardContentWelcome.new).declared_settings[:threshold].key?(:default)
  end

  def test_subclass_may_declare_a_setting_again
    block = Class.new(DashboardBlocks::NewsBlock) { setting :max_entries, **DashboardContent::MAX_ENTRIES_SETTING, max: 5 }

    assert_equal 5, block.settings_definitions[:max_entries][:max]
  end

  def test_query_list_blocks_declare_the_settings_of_their_form
    keys = DashboardContentWelcome.new.block_settings_definitions('issuequery').keys

    assert_equal %i[query_id max_entries auto_refresh own_columns columns], keys
  end

  # Without own columns the list follows the columns of its query
  def test_query_list_shows_the_columns_of_its_query
    queries(:queries_004).update! column_names: %i[tracker status]

    assert_equal %i[tracker status], query_list(columns: %w[subject]).query.column_names
  end

  def test_query_list_shows_its_own_columns
    query = query_list(own_columns: '1', columns: %w[subject]).query

    assert_equal %i[subject], query.column_names
  end

  private

  def query_list(**settings)
    DashboardContentWelcome.new.dashboard_block 'issuequery', settings: { query_id: queries(:queries_004).id.to_s, **settings }
  end
end
