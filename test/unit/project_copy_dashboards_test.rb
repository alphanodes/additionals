# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class ProjectCopyDashboardsTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001

    @source = projects :projects_001
    @target = Project.copy_from @source
    @target.identifier = 'copy-target'
    @target.name = 'Copy target'
  end

  def test_copy_copies_project_dashboards
    expected = @source.dashboards.where(dashboard_type: DashboardContentProject::TYPE_NAME).count

    assert_operator expected, :>, 0, 'fixture precondition: source project must have project dashboards'
    assert @target.copy(@source)

    assert_equal expected,
                 @target.dashboards.where(dashboard_type: DashboardContentProject::TYPE_NAME).count
  end

  def test_copy_preserves_dashboard_attributes
    source_dashboard = dashboards :private_project

    assert @target.copy(@source)

    copy = @target.dashboards.find_by name: source_dashboard.name

    assert_not_nil copy
    assert_equal source_dashboard.dashboard_type, copy.dashboard_type
    assert_equal source_dashboard.visibility, copy.visibility
    assert_equal source_dashboard.author_id, copy.author_id
    assert_equal @target.id, copy.project_id
    assert_not_equal source_dashboard.id, copy.id
  end

  def test_copy_keeps_original_author_even_when_current_user_differs
    User.current = users :users_002
    source_dashboard = dashboards :private_project

    assert @target.copy(@source)

    copy = @target.dashboards.find_by name: source_dashboard.name

    assert_equal source_dashboard.author_id, copy.author_id
    assert_not_equal User.current.id, copy.author_id
  end

  def test_copy_does_not_touch_welcome_dashboards
    welcome_count_before = Dashboard.welcome_only.count

    assert @target.copy(@source)

    assert_equal welcome_count_before, Dashboard.welcome_only.count
  end

  def test_copy_skips_global_project_dashboards_without_project_id
    assert @target.copy(@source)

    assert_empty @target.dashboards.where(name: 'Project default dashboard')
    assert_empty @target.dashboards.where(name: 'Private project default')
  end

  def test_copy_transfers_project_system_default
    source_dashboard = dashboards :private_project
    source_dashboard.update! visibility: Dashboard::VISIBILITY_PUBLIC, system_default: true

    assert @target.copy(@source)

    copy = @target.dashboards.find_by name: source_dashboard.name

    assert copy.system_default
    assert_equal @target.id, copy.project_id
  end

  def test_copy_keeps_locked_flag
    source_dashboard = dashboards :private_project
    source_dashboard.update_column :locked, true

    assert @target.copy(@source)

    copy = @target.dashboards.find_by name: source_dashboard.name

    assert copy.locked
  end

  def test_copy_deep_dups_layout_and_layout_settings
    source_dashboard = dashboards :private_project
    source_dashboard.update! layout: { 'left' => %w[text], 'right' => %w[news] }
    source_dashboard.update_block_settings 'text', title: 'Original title'
    source_dashboard.save!

    assert @target.copy(@source)

    copy = @target.dashboards.find_by name: source_dashboard.name

    assert_equal source_dashboard.layout, copy.layout
    assert_equal source_dashboard.layout_settings, copy.layout_settings

    # Mutating the copy must not bleed back into the source
    copy.layout['left'] << 'projectinformation'
    copy.layout_settings['text'][:title] = 'Changed in copy'

    assert_not_includes source_dashboard.reload.layout['left'], 'projectinformation'
    assert_equal 'Original title', source_dashboard.layout_settings['text'][:title]
  end

  def test_copy_transfers_role_ids_for_role_visibility
    source_dashboard = dashboards :private_project
    source_dashboard.update! visibility: Dashboard::VISIBILITY_ROLES, role_ids: [1, 2]

    assert @target.copy(@source)

    copy = @target.dashboards.find_by name: source_dashboard.name

    assert_equal Dashboard::VISIBILITY_ROLES, copy.visibility
    assert_equal [1, 2], copy.role_ids.sort
  end
end
