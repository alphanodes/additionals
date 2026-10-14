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

  # Asset URLs of every library, for loading a library on demand in the browser
  # (AdditionalsHelpers.loadLibrary). Needed where the libraries in the head
  # cannot know in advance, e.g. a block that only needs a library with
  # certain settings.
  def additionals_library_urls
    Additionals::LibraryRegistry.names.index_with do |name|
      Additionals::LibraryRegistry.resolve(name).map { |asset| { type: asset.type, url: additionals_asset_url(asset) } }
    end
  end

  private

  # Same paths as javascript_include_tag and stylesheet_link_tag with plugin: of Redmine
  def additionals_asset_url(asset)
    path = asset.core ? asset.path : "plugin_assets/#{asset.plugin}/#{asset.path}"
    asset.type == :css ? stylesheet_path(path) : javascript_path(path)
  end

  def additionals_include_asset(asset)
    key = [asset.type, asset.path, asset.plugin]
    return if additionals_loaded_assets.include? key

    additionals_loaded_assets << key

    case asset.type
    when :js then javascript_include_tag asset.path, plugin: asset.core ? nil : asset.plugin
    when :css then stylesheet_link_tag asset.path, plugin: asset.plugin
    end
  end

  def additionals_loaded_assets
    @additionals_loaded_assets ||= Set.new
  end
end
