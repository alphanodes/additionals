# frozen_string_literal: true

module Additionals
  # Catalogues every CSS / JS asset that `additionals_library_load` can
  # request, both as named packages (the public API used by block definitions
  # and view templates) and as underscore-prefixed atoms (the actual file
  # references). Packages may reference other packages; resolution flattens
  # the graph into an ordered, deduplicated list of Asset records.
  #
  # This module is pure data + resolution. Tag generation, view context and
  # per-request "already loaded" tracking live in AdditionalsAssetLoaderHelper.
  module LibraryRegistry
    Asset = Data.define :type, :path, :core, :plugin do
      # core: false by default -- only Redmine-core assets (asset path under
      # public/javascripts vs public/plugin_assets/additionals) set core:true.
      # plugin: which plugin ships the file (asset path lives under
      # public/plugin_assets/<plugin>). Defaults to 'additionals' so the
      # built-in atoms below stay unchanged; sister plugins registering their
      # own packages pass their own plugin id. Ignored for core assets.
      def initialize(type:, path:, core: false, plugin: 'additionals')
        super
      end
    end

    # Composite packages: each name maps to an ordered list of other package
    # names (or atom names). Names appearing here form the public API.
    PACKAGES = {
      chartjs: %i[_chartjs_core_umd _chartjs_colorschemes],
      chartjs_meta: %i[chartjs _chartjs_datalabels _chartjs_annotation],
      chartjs_moment: %i[_moment_with_locales _chartjs_adapter_moment],
      chartjs_matrix: %i[chartjs_moment _chartjs_chart_matrix],
      select2: %i[_select2_css _select2_js _select2_helpers],
      mermaid: %i[_mermaid_min _mermaid_load],
      dhtmlxgantt: %i[_dhtmlxgantt_css _dhtmlxgantt_js],
      font_awesome: %i[_font_awesome_css],
      actioncable: %i[_actioncable_core],
      d3plus: %i[_d3plus_min],
      sortable: %i[_sortable_min],
      # Single-atom packages kept for granular use (e.g. blocks that want only
      # one chartjs plugin on top of the chartjs base).
      chartjs_colorschemes: %i[_chartjs_colorschemes],
      chartjs_datalabels: %i[_chartjs_datalabels],
      chartjs_annotation: %i[_chartjs_annotation]
    }.freeze

    # Leaf entries -- one entry per real file include. Underscore-prefixed by
    # convention to mark them internal; block definitions and view templates
    # should reference PACKAGES, not ATOMS.
    # rubocop: disable Layout/HashAlignment
    ATOMS = {
      _chartjs_core_umd:       Asset.new(type: :js,  path: 'vendor/chart.umd'),
      _chartjs_colorschemes:   Asset.new(type: :js,  path: 'vendor/chartjs-plugin-colorschemes.min'),
      _chartjs_datalabels:     Asset.new(type: :js,  path: 'vendor/chartjs-plugin-datalabels.min'),
      _chartjs_annotation:     Asset.new(type: :js,  path: 'vendor/chartjs-plugin-annotation.min'),
      _moment_with_locales:    Asset.new(type: :js,  path: 'vendor/moment-with-locales.min'),
      _chartjs_adapter_moment: Asset.new(type: :js,  path: 'vendor/chartjs-adapter-moment.min'),
      _chartjs_chart_matrix:   Asset.new(type: :js,  path: 'vendor/chartjs-chart-matrix.min'),
      _d3plus_min:             Asset.new(type: :js,  path: 'vendor/d3plus.min'),
      _sortable_min:           Asset.new(type: :js,  path: 'vendor/sortable.min'),
      _actioncable_core:       Asset.new(type: :js,  path: 'actioncable', core: true),
      _mermaid_min:            Asset.new(type: :js,  path: 'vendor/mermaid.min'),
      _mermaid_load:           Asset.new(type: :js,  path: 'mermaid_load'),
      _select2_js:             Asset.new(type: :js,  path: 'vendor/select2.min'),
      _select2_helpers:        Asset.new(type: :js,  path: 'select2_helpers'),
      _dhtmlxgantt_js:         Asset.new(type: :js,  path: 'vendor/dhtmlxgantt'),
      _select2_css:            Asset.new(type: :css, path: 'select2'),
      _font_awesome_css:       Asset.new(type: :css, path: 'fontawesome-all.min'),
      _dhtmlxgantt_css:        Asset.new(type: :css, path: 'dhtmlxgantt')
    }.freeze
    # rubocop: enable Layout/HashAlignment

    class << self
      # Registers a package contributed by another plugin so it can be
      # requested via `additionals_library_load` / block `:libraries` exactly
      # like the built-in packages. `assets` is an ordered list whose entries
      # are either Asset records (leaf files) or Symbols (names of other
      # packages to pull in).
      #
      # Call this from a `config.to_prepare` block, NOT once at boot: this
      # class lives under an autoload path and is reloaded in development,
      # which wipes the registration. to_prepare re-runs after every reload
      # and repopulates the freshly loaded class.
      #
      # Raises if the name shadows a built-in package/atom so typos and
      # accidental collisions fail loudly. Re-registering the same name (e.g.
      # on reload) just overwrites the previous entry.
      def register(name, assets)
        name = name.to_sym
        raise ArgumentError, "Cannot register #{name.inspect}: name is a built-in package" if PACKAGES.key?(name) || ATOMS.key?(name)

        registered[name] = Array assets
      end

      # Resolves one or more package names into an ordered, deduplicated list
      # of Asset records. Unknown names raise ArgumentError -- block
      # definitions should fail loudly on typos, not silently load nothing.
      def resolve(names)
        seen_packages = Set.new
        seen_assets = Set.new
        result = []
        Array(names).each { |name| collect name.to_sym, result, seen_packages, seen_assets }
        result
      end

      private

      def registered
        @registered ||= {}
      end

      def collect(name, result, seen_packages, seen_assets)
        return if seen_packages.include? name

        seen_packages << name

        if registered.key? name
          registered[name].each do |entry|
            if entry.is_a? Asset
              add_asset entry, result, seen_assets
            else
              collect entry.to_sym, result, seen_packages, seen_assets
            end
          end
        elsif PACKAGES.key? name
          PACKAGES[name].each { |child| collect child, result, seen_packages, seen_assets }
        elsif (atom = ATOMS[name])
          add_asset atom, result, seen_assets
        else
          raise ArgumentError, "Unknown asset package: #{name.inspect}"
        end
      end

      def add_asset(atom, result, seen_assets)
        asset_key = [atom.type, atom.path, atom.plugin]
        return if seen_assets.include? asset_key

        seen_assets << asset_key
        result << atom
      end
    end
  end
end
