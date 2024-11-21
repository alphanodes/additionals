# frozen_string_literal: true

module AdditionalsJsHeadsHelper
  def stylesheet_link_tag(*sources)
    options = sources.last.is_a?(Hash) ? sources.last : {}
    return super if options[:plugin] || sources.exclude?('application')

    # add additionals variables.css to load before all themes
    sources.unshift 'plugin_assets/additionals/variables'
    super
  end
end
