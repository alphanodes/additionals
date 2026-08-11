# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class SettingsControllerTest < Additionals::ControllerTest
  def setup
    prepare_tests
    @request.session[:user_id] = 1
    @saved_settings = Setting.plugin_additionals.dup
  end

  def teardown
    Setting.plugin_additionals = @saved_settings
  end

  # A hash as it was stored before the setting existed: the key is simply not in it.
  # Redmine replaces the whole hash on save, so this is what every installation looks
  # like after a plugin update that adds a setting.
  def test_plugin_form_shows_the_default_of_a_setting_missing_in_the_stored_hash
    Setting.plugin_additionals = { global_wiki_sidebar: '' }

    get :plugin, params: { id: 'additionals' }

    assert_response :success
    assert_select 'input[name=?][checked=checked]', 'settings[open_external_urls]'
  end

  def test_plugin_form_keeps_a_stored_value_that_differs_from_the_default
    Setting.plugin_additionals = { open_external_urls: '0' }

    get :plugin, params: { id: 'additionals' }

    assert_response :success
    assert_select 'input[name=?][checked=checked]', 'settings[open_external_urls]', count: 0
  end

  # This is how the settings form stores them: the params arrive with string keys,
  # while the defaults of the plugin loader use symbols. Reading the form has to
  # find the stored value under either spelling.
  def test_plugin_form_shows_stored_values_of_a_hash_with_string_keys
    Setting.plugin_additionals = { 'global_wiki_sidebar' => 'Stored sidebar text',
                                   'open_external_urls' => '0' }

    get :plugin, params: { id: 'additionals' }

    assert_response :success
    assert_select 'textarea[name=?]', 'settings[global_wiki_sidebar]', text: 'Stored sidebar text'
    assert_select 'input[name=?][checked=checked]', 'settings[open_external_urls]', count: 0
  end

  def test_plugin_form_adds_a_missing_default_to_a_hash_with_string_keys
    Setting.plugin_additionals = { 'global_wiki_sidebar' => 'Stored sidebar text' }

    get :plugin, params: { id: 'additionals' }

    assert_response :success
    assert_select 'textarea[name=?]', 'settings[global_wiki_sidebar]', text: 'Stored sidebar text'
    assert_select 'input[name=?][checked=checked]', 'settings[open_external_urls]'
  end

  # Saving and reading back through the controller makes no assumption about how the
  # settings are stored, which is what the two tests above have to do.
  def test_plugin_form_shows_what_was_saved_through_the_form
    post :plugin, params: { id: 'additionals',
                            settings: { 'global_wiki_sidebar' => 'Saved through the form',
                                        'open_external_urls' => '0' } }

    assert_redirected_to plugin_settings_path('additionals')

    get :plugin, params: { id: 'additionals' }

    assert_response :success
    assert_select 'textarea[name=?]', 'settings[global_wiki_sidebar]', text: 'Saved through the form'
    assert_select 'input[name=?][checked=checked]', 'settings[open_external_urls]', count: 0
  end
end
