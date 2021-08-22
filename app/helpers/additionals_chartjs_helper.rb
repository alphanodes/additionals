# frozen_string_literal: true

module AdditionalsChartjsHelper
  def chartjs_colorschemes_info_url
    link_to(l(:label_chartjs_colorscheme_info),
            'https://nagix.github.io/chartjs-plugin-colorschemes/colorchart.html',
            class: 'external')
  end

  def select_options_for_chartjs_colorscheme(selected)
    data = YAML.safe_load(ERB.new(IO.read(File.join(Additionals.plugin_dir, 'config', 'colorschemes.yml'))).result) || {}
    grouped_options_for_select data, selected
  end
end
