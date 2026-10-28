# frozen_string_literal: true

module AdditionalsChartjsHelper
  def select_options_for_chartjs_colorscheme(selected)
    data = RedminePluginKit::Loader.new(plugin_id: 'additionals').yaml_config_load 'colorschemes.yml'
    grouped_options_for_select data, selected
  end

  # A select of the color schemes of Chart.js that shows the colors of each
  # scheme, in the list and in the closed field. The colors come from the
  # colorschemes plugin in the browser, which needs Chart.js itself.
  def chartjs_colorscheme_select_tag(name, selected, **options)
    safe_join [additionals_library_load(%i[select2 chartjs]),
               additionals_select2_tag(name,
                                       select_options_for_chartjs_colorscheme(selected),
                                       { format_state: 'formatColorScheme',
                                         format_selection: 'formatColorScheme' }.merge(options))]
  end
end
