# frozen_string_literal: true

module AdditionalsChartjsHelper
  def chartjs_colorschemes_info_url
    link_to_external l(:label_chartjs_colorscheme_info),
                     'https://nagix.github.io/chartjs-plugin-colorschemes/colorchart.html'
  end

  def select_options_for_chartjs_colorscheme(selected)
    data = RedminePluginKit::Loader.new(plugin_id: 'additionals').yaml_config_load 'colorschemes.yml'
    grouped_options_for_select data, selected
  end
end
