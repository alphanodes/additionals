# frozen_string_literal: true

module Additionals
  # Shared setup and session helpers for the plugins' browser tests.
  #
  # Every plugin used to repeat the same driven_by line with its own
  # environment variable name, which is how eight plugins ended up with eight
  # different names for the same switch. Extend this module in the plugin's
  # SystemTestCase and call use_plugin_system_test_driver instead.
  module GlobalSystemTestHelper
    # Extending also brings in the instance-level session helpers, so a plugin
    # needs the single extend line and nothing else.
    def self.extended(base)
      base.include SessionHelper
    end

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

    module SessionHelper
      # Signs in through the login page.
      #
      # Deliberately not scoped to "#login-form form" the way Redmine core does
      # it: every authentication plugin renders its own form into that
      # container through the view_account_login_form_top hook (WebAuthn, SAML,
      # ...), so the selector matches more than one element and Capybara raises
      # Capybara::Ambiguous. The fields below are unique on the page anyway.
      def log_user(login, password)
        visit '/login'

        # A session left open by an earlier test redirects /login away.
        return if page.has_no_selector? '#login-form', wait: 2

        fill_in 'username', with: login
        fill_in 'password', with: password

        assert_field 'username', with: login
        assert_field 'password', with: password

        find('#login-submit').click

        assert_no_selector '#login-form', wait: 10
      end
    end
  end
end
