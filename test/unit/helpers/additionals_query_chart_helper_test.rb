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

  # A chart may format its values itself, e.g. amounts with their currency
  def test_value_text_of_the_chart_wins
    labelled = Class.new Additionals::TestIssueQueryChart do
      def value_text(value) = "#{value} units"
    end
    chart = labelled.new project: projects(:projects_001), settings: { group_by: 'tracker' }

    assert_equal '3 units', @redmine_view.format_query_chart_value(chart, 3)
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

  def test_interval_options_offer_every_interval
    assert_equal AdditionalsQueryChart::INTERVALS.size,
                 Nokogiri::HTML.fragment(@redmine_view.options_for_query_chart_interval('month')).css('option').size
  end

  def test_settings_form_offers_an_interval
    assert_not_empty Nokogiri::HTML.fragment(render_settings_form).css('select[name="settings[chart][interval]"]')
  end

  # The form shows the interval and the timeline types only for these
  def test_settings_form_names_the_date_fields
    controller = Nokogiri::HTML.fragment(render_settings_form).at_css('[data-controller="additionals-chart-settings"]')

    assert_includes JSON.parse(controller['data-additionals-chart-settings-timeline-groups-value']), 'start_date'
  end

  def test_compare_options_offer_no_previous_period_without_a_period
    chart = Additionals::TestIssueQueryChart.new project: projects(:projects_001)
    html = build_redmine_view(WelcomeController).options_for_query_chart_compare chart, projects(:projects_001), nil

    assert_empty Nokogiri::HTML.fragment(html).css("option[value='#{AdditionalsQueryChart::PREVIOUS_PERIOD}']")
  end

  def test_compare_options_offer_the_previous_period_first
    chart = Additionals::TestPeriodIssueQueryChart.new project: projects(:projects_001)
    html = build_redmine_view(WelcomeController).options_for_query_chart_compare chart, projects(:projects_001), nil

    assert_equal AdditionalsQueryChart::PREVIOUS_PERIOD, Nokogiri::HTML.fragment(html).css('option')[1]['value']
  end

  # The label tells which date the period applies to
  def test_settings_form_names_the_date_of_the_period
    html = render_settings_form Additionals::TestPeriodIssueQueryChart

    assert_includes Nokogiri::HTML.fragment(html).at_css('label[for="settings_chart_period"]').text, ::I18n.t(:field_created_on)
  end

  def test_query_descriptions_link_the_query
    query = IssueQuery.create! name: 'Bugs', description: 'Bugs of the team', user: users(:users_001),
                               visibility: Query::VISIBILITY_PUBLIC
    chart = Additionals::TestIssueQueryChart.new project: projects(:projects_001),
                                                 settings: { group_by: 'tracker', query_id: query.id.to_s }
    html = Nokogiri::HTML.fragment @redmine_view.query_chart_query_descriptions(chart)

    assert_equal 'Bugs', html.at_css(".query-chart-query-description a[href*='query_id=#{query.id}']").text
  end

  def test_settings_form_offers_a_description
    assert_not_empty Nokogiri::HTML.fragment(render_settings_form).css('textarea[name="settings[chart][description]"]')
  end

  def test_settings_form_offers_class_bounds
    assert_not_empty Nokogiri::HTML.fragment(render_settings_form).css('input[name="settings[chart][classes]"]')
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

  def test_settings_form_offers_a_minimum_share
    assert_not_empty Nokogiri::HTML.fragment(render_settings_form).css('input[name="settings[chart][min_share]"]')
  end

  private

  # The form is part of the dashboard pages and rendered with their helpers
  def render_settings_form(chart_class = Additionals::TestIssueQueryChart)
    build_redmine_view(WelcomeController).render partial: 'dashboards/blocks/query_chart_settings',
                                                 locals: { block: 'chart',
                                                           settings: {},
                                                           block_definition: { query_chart: { class: chart_class } } }
  end
end
