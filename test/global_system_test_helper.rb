# frozen_string_literal: true

module Additionals
  # Shared driver setup for the plugins' browser tests.
  #
  # Every plugin used to repeat the same driven_by line with its own
  # environment variable name, which is how eight plugins ended up with eight
  # different names for the same switch. Extend this module in the plugin's
  # SystemTestCase and call use_plugin_system_test_driver instead.
  module GlobalSystemTestHelper
    # Locally the tests run headless so Chrome does not steal focus. Set
    # REDMINE_HEADLESS=false to watch a run in a visible browser.
    #
    # In CI a remote Selenium hub is configured through SELENIUM_REMOTE_URL.
    # Redmine core already wires that up in ApplicationSystemTestCase, together
    # with GOOGLE_CHROME_OPTS_ARGS, so the override has to step aside there:
    # calling driven_by would discard both and send the driver looking for a
    # local Chrome that does not exist in the job container.
    def use_plugin_system_test_driver(screen_size: [1400, 1400])
      return if ENV['SELENIUM_REMOTE_URL'].present?
      return if ENV['REDMINE_HEADLESS'] == 'false'

      driven_by :selenium, using: :headless_chrome, screen_size:
    end
  end
end
