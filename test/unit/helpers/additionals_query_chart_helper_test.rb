# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class AdditionalsQueryChartHelperTest < Additionals::HelperTest
  def setup
    super
    prepare_tests
    User.current = users :users_001
    @redmine_view = build_redmine_view
  end

  # The middle of a doughnut shows hours like the table, in the format of the user
  def test_payload_formats_hours_like_the_table
    Issue.where(project_id: 1).update_all estimated_hours: 1.5
    chart = Additionals::TestIssueQueryChart.new project: projects(:projects_001),
                                                 settings: { group_by: 'tracker', measure: 'estimated_hours' }

    assert_equal @redmine_view.format_hours(chart.total), @redmine_view.query_chart_payload(chart)[:totalText]
  end

  def test_payload_has_a_text_per_series
    query = IssueQuery.create! name: 'Bugs', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC
    chart = Additionals::TestIssueQueryChart.new project: projects(:projects_001),
                                                 settings: { group_by: 'tracker', compare_query_id: query.id.to_s,
                                                             chart_type: 'bar_vertical' }

    assert_equal 2, @redmine_view.query_chart_payload(chart)[:valueTexts].size
  end

  def test_chart_type_options_offer_every_type
    assert_equal AdditionalsQueryChart::CHART_TYPES.size,
                 Nokogiri::HTML.fragment(@redmine_view.options_for_query_chart_type('pie')).css('option').size
  end

  def test_table_of_values_lists_the_entries
    chart = Additionals::TestIssueQueryChart.new project: projects(:projects_001), settings: { group_by: 'tracker' }
    html = @redmine_view.render partial: 'dashboards/blocks/query_chart_table', locals: { chart: }

    assert_equal chart.entries.size, Nokogiri::HTML.fragment(html).css('tbody tr').size
  end

  # A chart without open only offers no such checkbox
  def test_settings_form_offers_open_only_only_if_supported
    assert_empty Nokogiri::HTML.fragment(render_settings_form).css('input[name="settings[chart][open_only]"]')
  end

  private

  # The form is part of the dashboard pages and rendered with their helpers
  def render_settings_form
    build_redmine_view(WelcomeController).render partial: 'dashboards/blocks/query_chart_settings',
                                                 locals: { block: 'chart',
                                                           settings: {},
                                                           block_definition: { query_chart: { class: Additionals::TestIssueQueryChart } } }
  end
end
