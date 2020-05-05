module Additionals
  MAX_CUSTOM_MENU_ITEMS = 5
  SELECT2_INIT_ENTRIES = 20

  GOTO_LIST = " \xc2\xbb".freeze
  LIST_SEPARATOR = GOTO_LIST + ' '

  class << self
    def setup
      incompatible_plugins(%w[redmine_issue_control_panel
                              redmine_editauthor
                              redmine_changeauthor
                              redmine_auto_watch])

      patch(%w[AccountController
               ApplicationController
               AutoCompletesController
               Issue
               IssuePriority
               TimeEntry
               Project
               Wiki
               WikiController
               ReportsController
               Principal
               QueryFilter
               Role
               User
               UserPreference])

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

      IssuesController.send(:helper, AdditionalsIssuesHelper)
      SettingsController.send(:helper, AdditionalsSettingsHelper)
      WikiController.send(:helper, AdditionalsWikiPdfHelper)
      CustomFieldsController.send(:helper, AdditionalsCustomFieldsHelper)

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
      load_macros(%w[cryptocompare date fa gist gmap google_docs group_users iframe
                     issue redmine_issue redmine_wiki
                     last_updated_at last_updated_by meteoblue member new_issue project
                     recently_updated reddit slideshare tradingview twitter user vimeo youtube asciinema])
    end

    def settings_compatible(plugin_name)
      if Setting[plugin_name].class == Hash
        # convert Rails 4 data (this runs only once)
        new_settings = ActiveSupport::HashWithIndifferentAccess.new(Setting[plugin_name])
        Setting.send("#{plugin_name}=", new_settings)
        new_settings
      else
        # Rails 5 uses ActiveSupport::HashWithIndifferentAccess
        Setting[plugin_name]
      end
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
      true?(setting(value))
    end

    def true?(value)
      return false if value.is_a? FalseClass
      return true if value.is_a?(TrueClass) || value.to_i == 1 || value.to_s.casecmp('true').zero?

      false
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
        raise "\n\033[31m#{title} plugin cannot be used with #{plugin} plugin'.\033[0m" if Redmine::Plugin.installed?(plugin)
      end
    end

    def patch(patches = [], plugin_id = 'additionals')
      patches.each do |name|
        patch_dir = Rails.root.join("plugins/#{plugin_id}/lib/#{plugin_id}/patches")
        require "#{patch_dir}/#{name.underscore}_patch"

        target = name.constantize
        patch = "#{plugin_id.camelize}::Patches::#{name}Patch".constantize

        target.include(patch) unless target.included_modules.include?(patch)
      end
    end

    def load_macros(macros = [], plugin_id = 'additionals')
      macro_dir = Rails.root.join("plugins/#{plugin_id}/lib/#{plugin_id}/wiki_macros")
      macros.each do |macro|
        require_dependency "#{macro_dir}/#{macro.underscore}_macro"
      end
    end

    def load_settings(plugin_id = 'additionals')
      cached_settings_name = '@load_settings_' + plugin_id
      cached_settings = instance_variable_get(cached_settings_name)
      if cached_settings.nil?
        data = YAML.safe_load(ERB.new(IO.read(Rails.root.join("plugins/#{plugin_id}/config/settings.yml"))).result) || {}
        instance_variable_set(cached_settings_name, data.symbolize_keys)
      else
        cached_settings
      end
    end

    def hash_remove_with_default(field, options, default = nil)
      value = nil
      if options.key? field
        value = options[field]
        options.delete(field)
      elsif !default.nil?
        value = default
      end
      [value, options]
    end

    private

    def settings
      settings_compatible(:plugin_additionals)
    end
  end
end
