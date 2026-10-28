# frozen_string_literal: true

module AdditionalsChartjsHelper
  # A scheme chosen before that is no longer offered stays in its group. The
  # value of an option is the key the library knows the colors by.
  def select_options_for_chartjs_colorscheme(selected)
    data = RedminePluginKit::Loader.new(plugin_id: 'additionals').yaml_config_load 'colorschemes.yml'
    if selected.present? && data.values.none? { |schemes| schemes.include? selected }
      group = data.keys.find { |name| name.casecmp? selected.split('.').first }
      data[group] = [*data[group], selected] if group
    end
    options = data.transform_values { |schemes| colorscheme_names(schemes).zip schemes }
    grouped_options_for_select options, selected
  end

  # The number at the end of a key is the count of colors, which the swatches
  # show; it stays where two palettes of a group would get the same name, e.g.
  # Tableau10 and Tableau20
  def colorscheme_names(schemes)
    counts = schemes.map { |scheme| scheme.sub(/\d+\z/, '') }.tally
    schemes.map do |scheme|
      base = scheme.sub(/\d+\z/, '')
      counts[base] > 1 ? scheme : base
    end
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
