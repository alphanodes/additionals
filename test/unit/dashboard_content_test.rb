# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DashboardContentTest < Additionals::TestCase
  def setup
    prepare_tests
  end

  def test_types
    assert_includes DashboardContent.types, DashboardContentProject::TYPE_NAME
    assert_includes DashboardContent.types, DashboardContentWelcome::TYPE_NAME
  end

  def test_full_width_group
    content = DashboardContent.new

    assert content.full_width_group?('top')
    assert content.full_width_group?('bottom')
    assert_not content.full_width_group?('left')
    assert_not content.full_width_group?('right')
  end

  def test_column_groups
    assert_equal %w[left right], DashboardContent.new.column_groups
  end
end
