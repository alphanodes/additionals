# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# A chart with an evaluation of its own hands its payload to the
# additionals-chart controller through the shared partial
class AdditionalsChartTest < Additionals::HelperTest
  def setup
    super
    prepare_tests
    User.current = users :users_001
    @redmine_view = build_redmine_view
  end

  def test_icon_follows_the_type
    assert_equal 'chart-area', Additionals::TestPayloadChart.new(type: 'area').icon
  end

  def test_icon_of_other_types_is_bars
    assert_equal 'chart-bar', Additionals::TestPayloadChart.new(type: 'bar_vertical').icon
  end

  def test_partial_hands_the_payload_to_the_controller
    html = render_chart Additionals::TestPayloadChart.new

    assert_equal 'Pages', JSON.parse(chart_element(html)['data-additionals-chart-payload-value'])['datasets'].first['label']
  end

  def test_partial_has_no_script
    assert_not_includes render_chart(Additionals::TestPayloadChart.new), '<script'
  end

  def test_partial_sets_the_height_of_the_chart
    assert_includes chart_element(render_chart(Additionals::TestPayloadChart.new))['style'],
                    "height: #{AdditionalsChart::CHART_DEFAULT_HEIGHT}px"
  end

  def test_partial_without_data_shows_no_chart
    assert_includes render_chart(Additionals::TestPayloadChart.new(data: [0, 0])), 'nodata'
  end

  def test_charts_side_by_side_get_an_id_each
    html = @redmine_view.render partial: 'additionals/charts/charts',
                                locals: { charts: [Additionals::TestPayloadChart.new, Additionals::TestPayloadChart.new],
                                          id: 'estimation' }
    ids = Nokogiri::HTML.fragment(html).css('.additionals-charts [data-controller="additionals-chart"]').pluck('id')

    assert_equal %w[estimation-0 estimation-1], ids
  end

  private

  def render_chart(chart)
    @redmine_view.render partial: 'additionals/charts/chart', locals: { chart:, id: 'wiki_chart' }
  end

  def chart_element(html)
    Nokogiri::HTML.fragment(html).at_css '#wiki_chart[data-controller="additionals-chart"]'
  end
end
