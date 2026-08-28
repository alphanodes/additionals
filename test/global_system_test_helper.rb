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

      driven_by :selenium, using: :headless_chrome, screen_size: do |driver_option|
        chrome_preferences.each { |name, value| driver_option.add_preference name, value }
      end
    end

    private

    # driven_by replaces Redmine's whole driver registration instead of adding
    # to it, so the preferences core sets in ApplicationSystemTestCase have to
    # be repeated here.
    #
    # password_manager_leak_detection is the one that hurts: the fixture
    # passwords are well known leaked ones, so after the first login Chrome
    # opens its "change your password" bubble. That bubble is browser UI, it
    # shows up neither in the DOM nor in a failure screenshot, and while it is
    # open the page receives no real click and no keystroke any more. It
    # appears once per browser profile, so it silently breaks whichever test
    # the seed put first and no amount of waiting can repair that.
    def chrome_preferences
      downloads = ApplicationSystemTestCase::DOWNLOADS_PATH.gsub File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR

      { 'download.default_directory' => downloads,
        'download.prompt_for_download' => false,
        'plugins.plugins_disabled' => ['Chrome PDF Viewer'],
        'profile.password_manager_leak_detection' => false,
        'profile.password_manager_enabled' => false,
        'credentials_enable_service' => false }
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
        if page.has_selector? '#login-form', wait: 5
          fill_in 'username', with: login
          fill_in 'password', with: password

          assert_field 'username', with: login
          assert_field 'password', with: password

          find('#login-submit').click
        end

        # The account menu only exists for a logged in user. Asserting it is
        # what keeps a /login that did not render the form (error page, hiccup
        # between browser and application) from passing as a login: the test
        # would then run anonymously and fail several steps later with a
        # message that points anywhere but here.
        assert_selector '#account .dropdown-trigger', wait: 10
      end
    end
  end
end
