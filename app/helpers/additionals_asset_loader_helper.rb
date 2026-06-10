# frozen_string_literal: true

# Public helper API for loading the JS / CSS bundles the additionals plugin
# ships. Package names and resolution rules live in
# Additionals::LibraryRegistry; this helper only handles tag generation and
# per-request "already loaded" tracking so each include happens at most once
# per response, even when multiple blocks request overlapping packages.
module AdditionalsAssetLoaderHelper
  def additionals_library_load(module_names)
    safe_join(Additionals::LibraryRegistry.resolve(module_names).filter_map { |asset| additionals_include_asset(asset) })
  end

  private

  def additionals_include_asset(asset)
    key = [asset.type, asset.path]
    return if additionals_loaded_assets.include? key

    additionals_loaded_assets << key

    case asset.type
    when :js then javascript_include_tag asset.path, plugin: asset.core ? nil : 'additionals'
    when :css then stylesheet_link_tag asset.path, plugin: 'additionals'
    end
  end

  def additionals_loaded_assets
    @additionals_loaded_assets ||= Set.new
  end
end
