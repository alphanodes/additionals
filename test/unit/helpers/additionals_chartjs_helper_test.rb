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

  # The gradients of Brewer are made for maps, a category of a chart needs a
  # color of its own; the smaller sets of a category palette are its start
  def test_colorscheme_select_offers_the_category_palettes_of_brewer
    html = @redmine_view.select_options_for_chartjs_colorscheme 'tableau.Tableau10'

    assert_select_in html, 'optgroup[label=Brewer] option', 8
    assert_select_in html, 'option[value=?]', 'brewer.SetOne9'
    assert_select_in html, 'option[value=?]', 'brewer.YlGnBu9', count: 0
  end

  # The number at the end of a key is the count of colors, the swatches show it;
  # it stays where two palettes of a group would get the same name. The value
  # stays the key the library knows the colors by.
  def test_colorscheme_select_names_a_palette_without_its_size
    html = @redmine_view.select_options_for_chartjs_colorscheme 'brewer.YlGnBu9'

    assert_select_in html, 'option[value=?]', 'brewer.SetOne9', text: 'brewer.SetOne'
    assert_select_in html, 'option[value=?]', 'brewer.YlGnBu9', text: 'brewer.YlGnBu'
    assert_select_in html, 'option[value=?]', 'office.Adjacency6', text: 'office.Adjacency'
    assert_select_in html, 'option[value=?]', 'tableau.ColorBlind10', text: 'tableau.ColorBlind'
    assert_select_in html, 'option[value=?]', 'tableau.Tableau20', text: 'tableau.Tableau20'
  end

  # A scheme chosen before keeps its colors until someone picks another one
  def test_colorscheme_select_keeps_a_scheme_no_longer_offered
    html = @redmine_view.select_options_for_chartjs_colorscheme 'brewer.YlGnBu9'

    assert_select_in html, 'optgroup[label=Brewer] option[value=?][selected]', 'brewer.YlGnBu9'
  end

  # The colors come from the library in the browser, select2 shows them
  def test_colorscheme_select_loads_the_colors_and_select2
    html = @redmine_view.chartjs_colorscheme_select_tag 'settings[chart_color_schema]', 'tableau.Tableau10'

    assert_match(/src=.+chart\.umd/, html)
    assert_match(/src=.+chartjs-plugin-colorschemes/, html)
    assert_match(/src=.+select2\.min/, html)
  end
end
