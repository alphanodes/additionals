# frozen_string_literal: true

module Additionals
  module GlobalFixturesHelper
    def plugin_fixture_path
      "#{File.dirname __FILE__}/fixtures"
    end

    def fixtures(*table_names)
      return super if table_names.first == :all

      # Register the plugin fixture directory in fixture_paths so Rails' standard
      # fixture loader picks up the plugin's overrides - including in parallel
      # test workers (each with its own database). The plugin path is appended
      # after the default paths; in Rails' fixture glob expansion the later file
      # wins on filename collisions, so a plugin's queries.yml still overrides
      # Redmine core's queries.yml when both exist, and falls back to the core
      # file when the plugin has none.
      self.fixture_paths += [plugin_fixture_path] if respond_to?(:fixture_paths) && !fixture_paths.include?(plugin_fixture_path)

      super
    end

    def fixtures_list
      if use_transactional_tests
        redmine_fixtures_list + plugin_fixtures_list
      else
        # if use_transactional_tests = false custom fixtures in plugin directory does not work
        redmine_fixtures_list
      end
    end

    # NOTE: overwrite it for custom fixtures
    def plugin_fixtures_list
      []
    end

    def redmine_fixtures_list
      %i[users groups_users user_preferences email_addresses roles enumerations
         auth_sources tokens enabled_modules
         projects projects_trackers
         members member_roles news
         issues issue_statuses issue_categories issue_relations
         journals journal_details watchers attachments
         custom_fields custom_values custom_fields_projects custom_fields_trackers
         versions trackers workflows time_entries
         repositories changesets changes
         wikis wiki_pages wiki_contents wiki_content_versions
         queries]
    end
  end
end
