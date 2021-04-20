# frozen_string_literal: true

require 'additionals/version'

module Additionals
  MAX_CUSTOM_MENU_ITEMS = 5
  SELECT2_INIT_ENTRIES = 20
  DEFAULT_MODAL_WIDTH = '350px'
  GOTO_LIST = " \xc2\xbb"
  LIST_SEPARATOR = "#{GOTO_LIST} "

  class << self
    def setup
      RenderAsync.configuration.jquery = true

      incompatible_plugins %w[redmine_editauthor
                              redmine_changeauthor
                              redmine_auto_watch]

      patch %w[ApplicationController
               AutoCompletesController
               Issue
               IssuePriority
               TimeEntry
               Project
               Wiki
               ProjectsController
               WelcomeController
               ReportsController
               Principal
               Query
               QueryFilter
               Role
               User
               UserPreference]

      Redmine::WikiFormatting.format_names.each do |format|
        case format
        when 'markdown'
          Redmine::WikiFormatting::Markdown::HTML.include Patches::FormatterMarkdownPatch
          Redmine::WikiFormatting::Markdown::Helper.include Patches::FormattingHelperPatch
        when 'textile'
          Redmine::WikiFormatting::Textile::Formatter.include Patches::FormatterTextilePatch
          Redmine::WikiFormatting::Textile::Helper.include Patches::FormattingHelperPatch
        end
      end

      IssuesController.send :helper, AdditionalsIssuesHelper
      SettingsController.send :helper, AdditionalsSettingsHelper
      WikiController.send :helper, AdditionalsWikiPdfHelper
      CustomFieldsController.send :helper, AdditionalsCustomFieldsHelper

      # Static class patches
      Redmine::AccessControl.include Additionals::Patches::AccessControlPatch

      # Global helpers
      ActionView::Base.include Additionals::Helpers
      ActionView::Base.include AdditionalsFontawesomeHelper
      ActionView::Base.include AdditionalsMenuHelper
      ActionView::Base.include Additionals::AdditionalsSelect2Helper

      # Hooks
      require_dependency 'additionals/hooks'

      # Macros
      load_macros
    end

    # support with default setting as fall back
    def setting(value)
      if settings.key? value
        settings[value]
      else
        load_settings[value]
      end
    end

    def setting?(value)
      true? setting(value)
    end

    # required multiple times because of this bug: https://www.redmine.org/issues/33290
    def redmine_database_ready?(with_table = nil)
      ActiveRecord::Base.connection
    rescue ActiveRecord::NoDatabaseError
      false
    else
      with_table.nil? || ActiveRecord::Base.connection.table_exists?(with_table)
    end

    def true?(value)
      return false if value.is_a? FalseClass
      return true if value.is_a?(TrueClass) || value.to_i == 1 || value.to_s.casecmp('true').zero?

      false
    end

    def debug(message)
      return if Rails.env.production?

      msg = message.is_a?(String) ? message : message.inspect
      Rails.logger.debug "#{Time.current.strftime '%H:%M:%S'} DEBUG [#{caller_locations(1..1).first.label}]: #{msg}"
    end

    def class_prefix(klass)
      klass_name = klass.is_a?(String) ? klass : klass.name
      klass_name.underscore.tr '/', '_'
    end

    def now_with_user_time_zone(user = User.current)
      if user.time_zone.nil?
        Time.zone.now
      else
        user.time_zone.now
      end
    end

    def incompatible_plugins(plugins = [], title = 'additionals')
      plugins.each do |plugin|
        raise "\n\033[31m#{title} plugin cannot be used with #{plugin} plugin.\033[0m" if Redmine::Plugin.installed? plugin
      end
    end

    def patch(patches = [], plugin_id = 'additionals')
      patches.each do |name|
        patch_dir = Rails.root.join "plugins/#{plugin_id}/lib/#{plugin_id}/patches"
        require "#{patch_dir}/#{name.underscore}_patch"

        target = name.constantize
        patch = "#{plugin_id.camelize}::Patches::#{name}Patch".constantize

        target.include patch unless target.included_modules.include? patch
      end
    end

    def load_macros(plugin_id = 'additionals')
      Dir[File.join(plugin_dir(plugin_id),
                    'lib',
                    plugin_id,
                    'wiki_macros',
                    '**/*_macro.rb')].sort.each { |f| require f }
    end

    def plugin_dir(plugin_id = 'additionals')
      if Gem.loaded_specs[plugin_id].nil?
        File.join Redmine::Plugin.directory, plugin_id
      else
        Gem.loaded_specs[plugin_id].full_gem_path
      end
    end

    def load_settings(plugin_id = 'additionals')
      cached_settings_name = "@load_settings_#{plugin_id}"
      cached_settings = instance_variable_get cached_settings_name
      if cached_settings.nil?
        data = YAML.safe_load(ERB.new(IO.read(File.join(plugin_dir(plugin_id), '/config/settings.yml'))).result) || {}
        instance_variable_set cached_settings_name, data.symbolize_keys
      else
        cached_settings
      end
    end

    def hash_remove_with_default(field, options, default = nil)
      value = nil
      if options.key? field
        value = options[field]
        options.delete field
      elsif !default.nil?
        value = default
      end
      [value, options]
    end

    private

    def settings
      Setting[:plugin_additionals]
    end
  end

  # Run the classic redmine plugin initializer after rails boot
  class Plugin < ::Rails::Engine
    require 'deface'
    require 'emoji'
    require 'render_async'
    require 'rss'
    require 'slim'

    config.after_initialize do
      # engine_name could be used (additionals_plugin), but can
      # create some side effencts
      plugin_id = 'additionals'

      # if plugin is already in plugins directory, use this and leave here
      next if Redmine::Plugin.installed? plugin_id

      # gem is used as redmine plugin
      require File.expand_path '../init', __dir__
      AdditionalTags.setup
      Additionals::Gemify.install_assets plugin_id
      Additionals::Gemify.create_plugin_hint plugin_id
    end
  end
end
