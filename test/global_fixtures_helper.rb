# frozen_string_literal: true

module Additionals
  module GlobalFixturesHelper
    def plugin_fixture_path
      "#{File.dirname __FILE__}/fixtures"
    end

    def fixtures(*table_names)
      return super if table_names.first == :all

      dir = plugin_fixture_path
      files_to_load = table_names.select { |x| File.exist? File.join(dir, "#{x}.yml") }

      # Pre-load plugin fixtures into the connection pool's fixture cache.
      # Rails skips loading core's same-named fixture file when the name is
      # already cached (see ActiveRecord::FixtureSet.fixture_is_cached?), so
      # this gives us full-file override semantics: a plugin's queries.yml
      # replaces Redmine core's queries.yml entirely, no merge.
      load_plugin_fixtures = -> { files_to_load.each { |x| ActiveRecord::FixtureSet.create_fixtures dir, x } }
      load_plugin_fixtures.call

      # Rails parallel test workers each get their own database, connection
      # pool and fixture cache. Replay the pre-load in every worker's setup
      # so the override still wins there.
      parallelize_setup(&load_plugin_fixtures) if respond_to? :parallelize_setup

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
