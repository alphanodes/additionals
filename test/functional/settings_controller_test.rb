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
end
