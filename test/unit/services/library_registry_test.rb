# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

module Additionals
  class LibraryRegistryTest < Additionals::TestCase
    Registry = Additionals::LibraryRegistry

    def test_resolves_single_atom_package
      result = Registry.resolve :d3plus

      assert_equal 1, result.size
      assert_equal :js, result.first.type
      assert_equal 'd3plus.min', result.first.path
      assert_not result.first.core
    end

    def test_resolves_composite_package_in_order
      result = Registry.resolve :chartjs
      paths = result.map(&:path)

      assert_equal %w[chart.umd chartjs-plugin-colorschemes.min], paths
    end

    def test_resolves_nested_composite_package
      paths = Registry.resolve(:chartjs_meta).map(&:path)

      assert_equal %w[chart.umd
                      chartjs-plugin-colorschemes.min
                      chartjs-plugin-datalabels.min
                      chartjs-plugin-annotation.min],
                   paths
    end

    def test_resolves_chartjs_matrix_pulls_in_moment
      paths = Registry.resolve(:chartjs_matrix).map(&:path)

      assert_includes paths, 'moment-with-locales.min'
      assert_includes paths, 'chartjs-adapter-moment.min'
      assert_includes paths, 'chartjs-chart-matrix.min'
    end

    def test_dedups_across_multiple_packages
      paths = Registry.resolve(%i[chartjs chartjs]).map(&:path)

      assert_equal 2, paths.size
    end

    def test_dedups_across_overlapping_packages
      # chartjs_meta already includes chartjs; chartjs alongside it must not
      # add chart.umd a second time.
      paths = Registry.resolve(%i[chartjs_meta chartjs]).map(&:path)

      assert_equal paths.uniq, paths
      assert_includes paths, 'chart.umd'
    end

    def test_dedups_atoms_reachable_via_different_packages
      # Both chartjs (composite) and chartjs_colorschemes (single atom) point
      # at the same colorschemes file; resolution should emit it once.
      paths = Registry.resolve(%i[chartjs chartjs_colorschemes]).map(&:path)
      colorschemes_count = paths.count 'chartjs-plugin-colorschemes.min'

      assert_equal 1, colorschemes_count
    end

    def test_resolves_dhtmlxgantt_emits_css_and_js
      result = Registry.resolve :dhtmlxgantt
      types = result.map(&:type)

      assert_includes types, :css
      assert_includes types, :js
    end

    def test_marks_core_assets_with_core_flag
      actioncable = Registry.resolve(:actioncable).first

      assert actioncable.core, 'actioncable atom should set core:true'
    end

    def test_raises_for_unknown_package_name
      assert_raises ArgumentError do
        Registry.resolve :totally_not_a_real_package
      end
    end

    def test_resolve_accepts_single_symbol_or_array
      single = Registry.resolve :d3plus
      arr = Registry.resolve [:d3plus]

      assert_equal single.map(&:path), arr.map(&:path)
    end

    def test_resolve_accepts_string_names
      assert_equal Registry.resolve(:d3plus).map(&:path),
                   Registry.resolve('d3plus').map(&:path)
    end
  end
end
