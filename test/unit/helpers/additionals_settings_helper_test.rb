# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class AdditionalsSettingsHelperTest < Additionals::HelperTest
  def setup
    super
    # not @view, ActionView::TestCase keeps its own view there
    @redmine_view = build_redmine_view SettingsController
  end

  # A password of plugin settings is a key of another system, never the login of the user:
  # browsers must not fill a saved login into it
  def test_passwordfield_is_not_taken_for_a_login
    html = @redmine_view.additionals_settings_passwordfield :api_key

    assert_select_in html, 'input[type=password][name=?][autocomplete=new-password]', 'settings[api_key]'
  end

  def test_passwordfield_keeps_a_given_autocomplete
    html = @redmine_view.additionals_settings_passwordfield :api_key, autocomplete: 'off'

    assert_select_in html, 'input[type=password][autocomplete=off]'
  end
end
