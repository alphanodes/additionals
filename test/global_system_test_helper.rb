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
    # REDMINE_HEADLESS=false to watch a run in a visible browser, which leaves
    # core's registration in place.
    #
    # In CI a remote Selenium hub is configured through SELENIUM_REMOTE_URL.
    # driven_by replaces core's registration instead of adding to it, so
    # everything ApplicationSystemTestCase sets up for that case - the remote
    # url, the browser arguments from GOOGLE_CHROME_OPTS_ARGS, the preferences -
    # has to be repeated below, or the driver would go looking for a local
    # Chrome that does not exist in the job container.
    #
    # Registering it here rather than leaving CI to core is what keeps the
    # window at one size everywhere. Core opens 1024x900, and in that viewport
    # an element near the right edge of a clipping container - the last button
    # of the wiki toolbar, say - is outside it and Selenium reports it as not
    # visible. The test is then red in the job and green on every developer
    # machine.
    def use_plugin_system_test_driver(screen_size: [1400, 1400])
      return if ENV['REDMINE_HEADLESS'] == 'false'

      driven_by :selenium, using: browser_name, screen_size:, options: remote_options do |driver_option|
        chrome_arguments.each { |argument| driver_option.add_argument argument }
        chrome_preferences.each { |name, value| driver_option.add_preference name, value }
      end
    end

    private

    # A remote hub runs the browser in a container with its own display, so
    # headless is neither needed nor wanted there. Locally it is.
    def browser_name
      remote_hub? ? :chrome : :headless_chrome
    end

    def remote_hub?
      ENV['SELENIUM_REMOTE_URL'].present?
    end

    def remote_options
      return {} unless remote_hub?

      { url: ENV.fetch('SELENIUM_REMOTE_URL'), browser: :remote }
    end

    # The job passes what the container needs through this variable, among it
    # --disable-dev-shm-usage and the resolver rule that lets the browser reach
    # the application. Dropping it would break the session before the first
    # test runs.
    def chrome_arguments
      ENV['GOOGLE_CHROME_OPTS_ARGS'].to_s.split ','
    end

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
