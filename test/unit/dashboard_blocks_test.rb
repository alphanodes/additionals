# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

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

  def test_content_builds_its_definitions_from_the_blocks
    definition = DashboardContentProject.new(project: projects(:projects_001)).block_definitions['projectissues']

    assert_equal 'dashboards/blocks/project_issues', definition[:partial]
  end

  def test_unavailable_block_is_not_offered
    content = DashboardContentProject.new project: projects(:projects_002)
    content.project.update_columns description: '', homepage: ''
    content.project.custom_values.delete_all

    assert_not content.available_blocks.key?('projectinformation')
  end

  def test_query_list_block_translates_the_label_of_its_query
    definition = DashboardContentWelcome.new.block_definitions['issuequery']

    assert_equal I18n.t(:label_issue_plural), definition[:query_block][:label]
  end
end
