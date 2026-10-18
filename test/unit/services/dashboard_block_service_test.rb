# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class DashboardBlockServiceTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
  end

  def test_blocks_without_project_are_those_of_the_welcome_page
    assert_includes Additionals::DashboardBlockService.new.blocks.pluck(:id), 'news'
  end

  def test_blocks_with_project_are_those_of_project_dashboards
    assert_includes Additionals::DashboardBlockService.new(project: projects(:projects_001)).blocks.pluck(:id), 'projectissues'
  end

  def test_block_returns_its_data
    result = Additionals::DashboardBlockService.new.block 'text', settings: { title: 'Hello', text: 'World' }

    assert_equal({ title: 'Hello', text: 'World' }, result.block[:data])
  end

  def test_unknown_block_is_not_found
    assert_equal :not_found, Additionals::DashboardBlockService.new.block('unknown').status
  end

  def test_feed_with_own_url_is_forbidden_without_permission_to_save_dashboards
    Role.find_each { |role| role.remove_permission! :save_dashboards }
    User.current = users :users_002

    assert_equal :forbidden, Additionals::DashboardBlockService.new.block('feed', settings: { url: 'https://example.org' }).status
  end

  def test_invalid_setting_is_an_error
    assert_equal :invalid, Additionals::DashboardBlockService.new.block('news', settings: { max_entries: '5000' }).status
  end

  def test_unknown_setting_is_named
    result = Additionals::DashboardBlockService.new.block 'news', settings: { max_entry: '5' }

    assert_match(/\Amax_entry /, result.errors.first)
  end
end
