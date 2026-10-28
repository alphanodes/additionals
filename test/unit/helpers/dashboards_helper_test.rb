# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

# Test stub with blocks of the test, to exercise dashboard_required_libraries
# without the blocks of the plugins. Dashboard constantizes
# `DashboardContent#{dashboard_type.chomp('Dashboard')}` so the class name and
# TYPE_NAME below have to follow that convention -- which also requires this
# class to live at the top level, not nested inside the test. Named *Stub (not
# *Test) so it does not collide with DashboardContentTest in
# test/unit/dashboard_content_test.rb when the full plugin suite runs.
class DashboardContentStub < DashboardContent
  TYPE_NAME = 'StubDashboard'

  class << self
    # Block ids with the libraries of the block, nil for one rendered with the page
    attr_accessor :test_blocks
  end

  def blocks
    (self.class.test_blocks || {}).to_h { |id, libraries| [id, self.class.test_block(id, libraries).new(self)] }
  end

  def self.test_block(id, libraries)
    Class.new DashboardBlocks::Base do
      block_id id
      label { id }
      async(partial: 'dashboards/blocks/text_async', libraries:) if libraries
    end
  end
end

class DashboardsHelperTest < Additionals::HelperTest
  include DashboardsHelper

  def test_block_libraries_of_a_block_rendered_with_the_page_are_empty
    assert_equal [], block_libraries(DashboardContentStub.test_block('plain', nil).new(DashboardContentStub.new))
  end

  def test_block_libraries_of_a_block_loaded_after_the_page
    block = DashboardContentStub.test_block('chart', %i[chartjs_treemap mermaid]).new DashboardContentStub.new

    assert_equal %i[chartjs_treemap mermaid], block_libraries(block)
  end

  def test_dashboard_required_libraries_handles_nil_dashboard
    assert_equal [], dashboard_required_libraries(nil)
  end

  def test_dashboard_required_libraries_aggregates_across_layout
    dashboard = build_test_dashboard layout: { 'top' => %w[block_a block_b],
                                               'left' => %w[block_a block_c] },
                                     blocks: { 'block_a' => %i[chartjs_treemap], 'block_b' => %i[chartjs_meta], 'block_c' => %i[mermaid] }
    result = dashboard_required_libraries dashboard

    assert_includes result, :chartjs_treemap
    assert_includes result, :chartjs_meta
    assert_includes result, :mermaid
    assert_equal result.size, result.uniq.size
  end

  # Blocks added without a page reload cannot load their libraries themselves
  def test_dashboard_required_libraries_includes_addable_blocks_when_layout_editable
    User.current = users :users_001
    dashboard = build_test_dashboard layout: { 'top' => %w[block_a] },
                                     blocks: { 'block_a' => %i[chartjs_treemap], 'block_b' => %i[chartjs_meta] }

    assert_includes dashboard_required_libraries(dashboard), :chartjs_meta
  end

  def test_dashboard_required_libraries_skips_addable_blocks_when_layout_not_editable
    User.current = User.anonymous
    dashboard = build_test_dashboard layout: { 'top' => %w[block_a] },
                                     blocks: { 'block_a' => %i[chartjs_treemap], 'block_b' => %i[chartjs_meta] }

    assert_equal %i[chartjs_treemap], dashboard_required_libraries(dashboard)
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

  def test_block_select_tag_submits_through_stimulus
    # jQuery's .submit() calls the native form.submit(), which emits no submit
    # event and therefore bypasses the remote-form controller -- the block would
    # then be added through a full page reload instead of AJAX
    User.current = users :users_001
    select = parse_html dashboard_block_select_tag(build_test_dashboard(layout: {}, blocks: {})), 'select#block-select'

    assert_equal 'change->remote-form#submit', select['data-action']
    assert_nil select['onchange']
  end

  private

  def parse_html(html, selector)
    Nokogiri::HTML::DocumentFragment.parse(html).at_css selector
  end

  def build_test_dashboard(layout:, blocks:)
    DashboardContentStub.test_blocks = blocks
    Dashboard.new(name: 'Test', dashboard_type: DashboardContentStub::TYPE_NAME,
                  author_id: User.current.id).tap { |d| d.layout = layout }
  end
end
