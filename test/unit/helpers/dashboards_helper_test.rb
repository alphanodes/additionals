# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

# Test stub that exposes a fixed block_definitions hash so we can exercise
# dashboard_required_libraries without touching plugin patches. Dashboard
# constantizes `DashboardContent#{dashboard_type.chomp('Dashboard')}` so the
# class name and TYPE_NAME below have to follow that convention -- which also
# requires this class to live at the top level, not nested inside the test.
# Named *Stub (not *Test) so it does not collide with DashboardContentTest in
# test/unit/dashboard_content_test.rb when the full plugin suite runs.
class DashboardContentStub < DashboardContent
  TYPE_NAME = 'StubDashboard'

  class << self
    attr_accessor :test_blocks
  end

  def block_definitions
    self.class.test_blocks || {}
  end
end

class DashboardsHelperTest < Additionals::HelperTest
  include DashboardsHelper

  def test_block_libraries_returns_empty_for_minimal_config
    assert_equal [], block_libraries({})
  end

  def test_block_libraries_picks_up_top_level_libraries
    cfg = { libraries: %i[d3plus] }

    assert_equal %i[d3plus], block_libraries(cfg)
  end

  def test_block_libraries_picks_up_async_libraries
    cfg = { async: { partial: 'foo', libraries: %i[d3plus mermaid] } }

    assert_equal %i[d3plus mermaid], block_libraries(cfg)
  end

  def test_block_libraries_merges_top_level_and_async_libraries
    cfg = { libraries: %i[d3plus], async: { libraries: %i[mermaid] } }

    assert_equal %i[d3plus mermaid], block_libraries(cfg)
  end

  def test_block_libraries_dedups_across_top_level_and_async
    cfg = { libraries: %i[chartjs], async: { libraries: %i[chartjs d3plus] } }

    assert_equal %i[chartjs d3plus], block_libraries(cfg)
  end

  def test_block_libraries_ignores_data_check_class_and_matrix
    # Library loading is driven exclusively by :libraries. data_check_class
    # (min-height pre-check) and matrix (matrix-chart routing) must not act
    # as implicit triggers for asset loading.
    cfg = { matrix: { matrix_class: 'Foo' },
            async: { data_check_class: 'SomeChart' } }

    assert_equal [], block_libraries(cfg)
  end

  def test_dashboard_required_libraries_handles_nil_dashboard
    assert_equal [], dashboard_required_libraries(nil)
  end

  def test_dashboard_required_libraries_aggregates_across_layout
    dashboard = build_test_dashboard layout: { 'top' => %w[block_a block_b],
                                               'left' => %w[block_a block_c] },
                                     blocks: { 'block_a' => { libraries: %i[d3plus] },
                                               'block_b' => { async: { libraries: %i[chartjs_meta] } },
                                               'block_c' => { libraries: %i[mermaid] } }
    result = dashboard_required_libraries dashboard

    assert_includes result, :d3plus
    assert_includes result, :chartjs_meta
    assert_includes result, :mermaid
    assert_equal result.size, result.uniq.size
  end

  def test_dashboard_required_libraries_skips_unknown_blocks
    dashboard = build_test_dashboard layout: { 'top' => %w[ghost_block] },
                                     blocks: {}

    assert_equal [], dashboard_required_libraries(dashboard)
  end

  def test_render_dashboard_groups_skips_all_empty_groups_when_not_sortable
    dashboard = build_test_dashboard layout: {}, blocks: {}

    assert_predicate render_dashboard_groups(dashboard, can_sort: false), :blank?
  end

  def test_render_dashboard_groups_renders_all_empty_groups_when_sortable
    dashboard = build_test_dashboard layout: {}, blocks: {}
    result = render_dashboard_groups dashboard, can_sort: true

    assert_includes result, 'id="list-top"'
    assert_includes result, 'id="list-left"'
    assert_includes result, 'id="list-right"'
    assert_includes result, 'id="list-bottom"'
  end

  private

  def build_test_dashboard(layout:, blocks:)
    DashboardContentStub.test_blocks = blocks
    Dashboard.new(name: 'Test', dashboard_type: DashboardContentStub::TYPE_NAME,
                  author_id: User.current.id).tap { |d| d.layout = layout }
  end
end
