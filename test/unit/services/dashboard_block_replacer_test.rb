# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class DashboardBlockReplacerTest < Additionals::TestCase
  def setup
    prepare_tests
  end

  def test_replaces_a_block_at_the_same_place
    dashboard = dashboard_with %w[news old_chart activity]
    replace_old_chart_with [['new_chart', { group_by: 'tracker' }]]

    assert_equal %w[news new_chart activity], dashboard.reload.layout['left']
  end

  def test_takes_the_settings_of_the_new_block
    dashboard = dashboard_with %w[old_chart]
    replace_old_chart_with [['new_chart', { group_by: 'tracker' }]]

    assert_equal 'tracker', dashboard.reload.layout_settings('new_chart')[:group_by]
  end

  def test_drops_the_settings_of_the_old_block
    dashboard = dashboard_with %w[old_chart], 'old_chart' => { custom_fields: ['1'] }
    replace_old_chart_with [['new_chart', {}]]

    assert_not dashboard.reload.options[:layout_settings].key?('old_chart')
  end

  # Numbered like DashboardContent#block_options, after the blocks in use
  def test_numbers_several_new_blocks
    dashboard = dashboard_with %w[new_chart old_chart]
    replace_old_chart_with [['new_chart', {}], ['new_chart', {}]]

    assert_equal %w[new_chart new_chart__1 new_chart__2], dashboard.reload.layout['left']
  end

  def test_keeps_other_blocks
    dashboard = dashboard_with %w[news activity]
    replace_old_chart_with [['new_chart', {}]]

    assert_equal %w[news activity], dashboard.reload.layout['left']
  end

  def test_calendars_replace_a_block_placed_several_times
    dashboard = dashboard_with %w[old_matrix old_matrix__2], 'old_matrix__2' => { query_id: '5' }
    Additionals::DashboardBlockReplacer.replace_with_calendars 'old_matrix' => %w[issue_chart created_on]

    assert_equal %w[issue_chart issue_chart__1], dashboard.reload.layout['left']
  end

  def test_existing_custom_field_ids_skip_deleted_fields
    assert_equal ['1'], Additionals::DashboardBlockReplacer.existing_custom_field_ids(%w[1 999])
  end

  # The form stores an array, a rendering of the old block a comma list
  def test_existing_custom_field_ids_read_a_comma_list
    assert_equal %w[1 2], Additionals::DashboardBlockReplacer.existing_custom_field_ids('1, 2')
  end

  def test_chart_settings_show_a_pie_with_table
    assert_equal({ group_by: 'cf_1', chart_type: 'pie', show_empty: '1', with_table: '1' },
                 Additionals::DashboardBlockReplacer.chart_settings('cf_1'))
  end

  def test_rename_setting_moves_the_value
    dashboard = dashboard_with %w[server], 'server' => { name: 'Web', labels: 'prod' }
    Additionals::DashboardBlockReplacer.rename_setting %w[server], :name, :title

    assert_equal({ labels: 'prod', title: 'Web' }, dashboard.reload.layout_settings('server'))
  end

  def test_rename_setting_of_a_block_placed_more_than_once
    dashboard = dashboard_with %w[server server__1], 'server__1' => { name: 'Mail' }
    Additionals::DashboardBlockReplacer.rename_setting %w[server], :name, :title

    assert_equal({ title: 'Mail' }, dashboard.reload.layout_settings('server__1'))
  end

  def test_rename_setting_keeps_string_keys
    dashboard = dashboard_with %w[server], 'server' => { 'name' => 'Web' }
    Additionals::DashboardBlockReplacer.rename_setting %w[server], :name, :title

    assert_equal({ 'title' => 'Web' }, dashboard.reload.layout_settings('server'))
  end

  def test_rename_setting_drops_a_blank_value
    dashboard = dashboard_with %w[server], 'server' => { name: '' }
    Additionals::DashboardBlockReplacer.rename_setting %w[server], :name, :title

    assert_empty dashboard.reload.layout_settings('server')
  end

  def test_rename_setting_keeps_other_blocks
    dashboard = dashboard_with %w[contact], 'contact' => { name: 'Mine' }
    Additionals::DashboardBlockReplacer.rename_setting %w[server], :name, :title

    assert_equal({ name: 'Mine' }, dashboard.reload.layout_settings('contact'))
  end

  private

  def replace_old_chart_with(replacements)
    Additionals::DashboardBlockReplacer.call { |block, _settings| replacements if block == 'old_chart' }
  end

  def dashboard_with(blocks, layout_settings = {})
    dashboard = Dashboard.create! name: "blocks #{blocks.join}",
                                  dashboard_type: DashboardContentWelcome::TYPE_NAME,
                                  author: users(:users_001),
                                  visibility: Dashboard::VISIBILITY_PUBLIC
    dashboard.update_column :options, { layout: { 'left' => blocks }, layout_settings: }
    dashboard
  end
end
