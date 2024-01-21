# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class RedminePluginKitLoaderTest < Additionals::TestCase
  def setup
    @plugin_id = 'additionals'
  end

  def test_add_patch
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_patch 'Issue'

    assert loader.apply!
  end

  def test_add_patch_as_hash
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_patch({ target: Issue, patch: 'Issue' })

    assert loader.apply!
  end

  def test_add_patch_as_hash_without_patch
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_patch({ target: Issue })

    assert loader.apply!
  end

  def test_add_multiple_patches
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_patch %w[Issue User]

    assert loader.apply!
  end

  def test_add_invalid_patch
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_patch 'Issue2'

    assert_raises NameError do
      loader.apply!
    end
  end

  def test_add_helper
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_helper 'Settings'

    assert loader.apply!
  end

  def test_add_helper_as_hash
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_helper({ controller: SettingsController, helper: SettingsHelper })

    assert loader.apply!
  end

  def test_add_helper_as_hash_as_string
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_helper({ controller: 'Settings', helper: 'Settings' })

    assert loader.apply!
  end

  def test_add_helper_as_hash_controller_only
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_helper({ controller: SettingsController })

    assert loader.apply!
  end

  def test_add_helper_as_hash_controller_only_string
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_helper({ controller: 'Settings' })

    assert loader.apply!
  end

  def test_require_files_for_lib
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id

    spec = File.join 'wiki_macros', '**/*_macro.rb'
    files = loader.require_files spec

    assert files.count.positive?
    assert(files.detect { |file| file.include? 'fa_macro' })
  end

  def test_require_files_for_app
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id

    spec = File.join 'helpers', '**/additionals_*.rb'
    files = loader.require_files spec, use_app: true

    assert files.count.positive?
    assert(files.detect { |file| file.include? 'additionals_clipboardjs_helper' })
  end

  def test_apply_without_data
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id

    assert loader.apply!
  end

  def test_apply
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_helper 'Settings'
    loader.add_patch 'Issue'
    loader.add_global_helper Additionals::Helpers

    assert loader.apply!
  end

  def test_do_not_allow_helper_if_controller_patch_exists
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_patch 'ProjectsController'
    loader.add_helper 'Projects'

    assert_raises RedminePluginKit::Loader::ExistingControllerPatchForHelper do
      assert loader.apply!
    end
  end

  def test_do_not_allow_helper_if_controller_patch_exists_as_hash
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    loader.add_patch 'ProjectsController'
    loader.add_helper({ controller: ProjectsController, helper: 'Settings' })

    assert_raises RedminePluginKit::Loader::ExistingControllerPatchForHelper do
      assert loader.apply!
    end
  end

  def test_load_model_hooks
    hooks = RedminePluginKit::Loader.new(plugin_id: @plugin_id).load_model_hooks!

    assert_kind_of Module, hooks
  end

  def test_load_hooks
    hooks = RedminePluginKit::Loader.new(plugin_id: @plugin_id).load_view_hooks!

    assert_kind_of Module, hooks
  end

  def test_load_macros
    loader = RedminePluginKit::Loader.new plugin_id: @plugin_id
    macros = loader.load_macros!

    assert macros.count.positive?
    assert(macros.detect { |macro| macro.include? 'fa_macro' })
  end
end
