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
      base.include SelectFieldHelper
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

    # Select fields of additionals as a user works with them. Tests of plugins
    # use these instead of the markup of the library behind the fields, which
    # only additionals knows - here, in SELECT_FIELD_MARKUP.
    module SelectFieldHelper
      SELECT_FIELD_MARKUP = {
        field: '.additionals-select-field',
        multiple: '.select2-selection--multiple',
        opener: '.select2-selection',
        open_field: '.select2-container--open',
        focused_search: '.select2-container--open .select2-search__field:focus',
        entry: '.select2-results__option[role="option"]',
        choice: '.select2-selection__choice',
        choice_remove: '.select2-selection__choice__remove',
        shown: '.select2-selection__rendered',
        clear: '.select2-selection__clear'
      }.freeze

      # Opens the select field inside +container+ (selector or element), types
      # +search+ (if any) and picks the entry +text+. Entries with more than
      # their name (contacts with an address) need exact: false.
      def choose_select_entry(container, text, search: nil, exact: true)
        open_select_field container
        type_into_open_select search if search
        choose_open_select_entry text, exact:
      end

      # Opens the select field inside +container+
      def open_select_field(container)
        # removing a chosen entry already opens the field, a click would close it
        within container do
          find(SELECT_FIELD_MARKUP[:opener]).click unless has_css? SELECT_FIELD_MARKUP[:open_field], wait: 0
        end
      end

      # Types +text+ (or keys like :backspace) into the search of the open
      # field. Opening moves the focus into the search field, a single select
      # only right after it opened. An empty multiple field makes that search
      # field too small to count as visible, so the keys go to the focused
      # field, as they do for a user.
      def type_into_open_select(text)
        page.document.assert_selector SELECT_FIELD_MARKUP[:focused_search], visible: :all
        page.active_element.send_keys text
      end

      # Leaves the open field with Tab, as a user goes on to the next field
      def leave_select_field
        page.active_element.send_keys :tab
      end

      # Picks the entry +text+ of the open list, e.g. of a menu opened by a
      # button (AdditionalsSelect.menu)
      def choose_open_select_entry(text, exact: true)
        select_entry(text, exact:).click
      end

      # The open list offers the entry +text+
      def assert_select_entry(text, exact: true)
        assert select_entry(text, exact:)
      end

      # No open list offers the entry +text+, e.g. after a menu went away
      def assert_no_select_entry(text, exact: true)
        page.document.assert_no_selector SELECT_FIELD_MARKUP[:entry], text:, exact_text: exact
      end

      # The select field inside +container+ shows exactly the chosen entries
      # +texts+, in this order; none for an empty field
      def assert_select_chosen(container, *texts)
        within container do
          field = find SELECT_FIELD_MARKUP[:field]
          if field.has_css? SELECT_FIELD_MARKUP[:multiple], wait: 0
            # the title holds the text of the entry alone, without the remove button
            # retried until the field shows them, it may still be rendering
            field.synchronize do
              chosen = field.all(SELECT_FIELD_MARKUP[:choice], wait: 0).pluck(:title)
              raise Capybara::ExpectationNotMet, "chosen #{chosen.inspect}, expected #{texts.inspect}" if chosen != texts
            end

            assert_equal texts, field.all(SELECT_FIELD_MARKUP[:choice]).pluck(:title)
          elsif texts.empty?
            # shows the placeholder or nothing, never a chosen entry
            field.assert_selector(SELECT_FIELD_MARKUP[:shown]) { |shown| shown[:title].blank? }
          else
            field.assert_selector(SELECT_FIELD_MARKUP[:shown]) { |shown| shown[:title] == texts.first }
          end
        end
      end

      # Removes the chosen entry +text+ of the multiple select field inside
      # +container+
      def remove_select_entry(container, text)
        within container do
          choice = find(SELECT_FIELD_MARKUP[:choice]) { |element| element[:title] == text }
          choice.find(SELECT_FIELD_MARKUP[:choice_remove]).click
        end
      end

      # Empties the single select field inside +container+ with its clear
      # button (allow_clear)
      def clear_select_field(container)
        within(container) { find(SELECT_FIELD_MARKUP[:clear]).click }
      end

      # Types +name+ into the tag field inside +container+ and takes it, as a
      # new tag or as the existing one of that name
      def add_select_tag(container, name)
        choose_select_entry container, name, search: name
      end

      private

      # The entries open at the end of the body, also for a field inside a
      # dialog, so they are searched outside any within block; groups of
      # entries are skipped
      def select_entry(text, exact:)
        page.document.find SELECT_FIELD_MARKUP[:entry], text:, exact_text: exact
      end
    end
  end
end
