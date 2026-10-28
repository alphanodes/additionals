# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

# Called on the view Redmine builds for its settings pages
class AdditionalsChartjsHelperTest < Additionals::HelperTest
  def setup
    super
    @redmine_view = build_redmine_view SettingsController
  end

  def test_colorscheme_select_shows_each_scheme_with_its_colors
    html = @redmine_view.chartjs_colorscheme_select_tag 'settings[chart_color_schema]', 'tableau.Tableau10'

    assert_select_in html, 'select[name=?] option[value=?][selected]', 'settings[chart_color_schema]', 'tableau.Tableau10'
    assert_match(/select2Tag\('settings_chart_color_schema', .*"format_state":"formatColorScheme"/, html)
    assert_match(/"format_selection":"formatColorScheme"/, html)
  end

  # The colors come from the library in the browser, select2 shows them
  def test_colorscheme_select_loads_the_colors_and_select2
    html = @redmine_view.chartjs_colorscheme_select_tag 'settings[chart_color_schema]', 'tableau.Tableau10'

    assert_match(/src=.+chart\.umd/, html)
    assert_match(/src=.+chartjs-plugin-colorschemes/, html)
    assert_match(/src=.+select2\.min/, html)
  end
end
