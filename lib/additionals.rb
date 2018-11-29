module Additionals
  MAX_CUSTOM_MENU_ITEMS = 5
  SELECT2_INIT_ENTRIES = 20

  LIST_SEPARATOR = ' &#187; '.html_safe # rubocop:disable Rails/OutputSafety

  class << self
    def setup
      incompatible_plugins(%w[redmine_tweaks
                              redmine_issue_control_panel
                              redmine_editauthor
                              redmine_changeauthor
                              redmine_auto_watch])
      patch(%w[AccountController
               Issue
               IssuePriority
               TimeEntry
               Wiki
               WikiController
               UserPreference])

      patch(%w[QueryFilter]) if Redmine::VERSION.to_s >= '3.4'

      Rails.configuration.assets.paths << Emoji.images_path
      Redmine::WikiFormatting.format_names.each do |format|
        case format
        when 'markdown'
          Redmine::WikiFormatting::Markdown::HTML.send(:include, Patches::FormatterMarkdownPatch)
          Redmine::WikiFormatting::Markdown::Helper.send(:include, Patches::FormattingHelperPatch)
        when 'textile'
          Redmine::WikiFormatting::Textile::Formatter.send(:include, Patches::FormatterTextilePatch)
          Redmine::WikiFormatting::Textile::Helper.send(:include, Patches::FormattingHelperPatch)
        end
      end

      # Static class patches
      IssuesController.send(:helper, AdditionalsIssuesHelper)
      WikiController.send(:helper, AdditionalsWikiPdfHelper)
      Redmine::AccessControl.send(:include, Additionals::Patches::AccessControlPatch)

      # Global helpers
      ActionView::Base.send :include, Additionals::Helpers
      ActionView::Base.send :include, AdditionalsFontawesomeHelper
      ActionView::Base.send :include, AdditionalsMenuHelper

      # Hooks
      require_dependency 'additionals/hooks'

      # Macros
      load_macros(%w[calendar cryptocompare date fa gist gmap group_users iframe
                     issue redmine_issue redmine_wiki
                     last_updated_at last_updated_by meteoblue member new_issue project
                     recently_updated reddit slideshare tradingview twitter user vimeo youtube])
    end

    def settings
      if Rails.version >= '5.2'
        Setting[:plugin_additionals]
      else
        ActionController::Parameters.new(Setting[:plugin_additionals])
      end
    end

    def setting?(value)
      true?(settings[value])
    end

    def true?(value)
      return true if value.to_i == 1 || value.to_s.casecmp('true').zero?

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
        patch_dir = Rails.root.join('plugins', plugin_id, 'lib', plugin_id, 'patches')
        require "#{patch_dir}/#{name.underscore}_patch"

        target = name.constantize
        patch = "#{plugin_id.camelize}::Patches::#{name}Patch".constantize

        target.send(:include, patch) unless target.included_modules.include?(patch)
      end
    end

    def load_macros(macros = [], plugin_id = 'additionals')
      macro_dir = Rails.root.join('plugins', plugin_id, 'lib', plugin_id, 'wiki_macros')
      macros.each do |macro|
        require_dependency "#{macro_dir}/#{macro.underscore}_macro"
      end
    end

    def load_settings(plugin_id = 'additionals')
      data = YAML.safe_load(ERB.new(IO.read(Rails.root.join('plugins',
                                                            plugin_id,
                                                            'config',
                                                            'settings.yml'))).result) || {}
      data.symbolize_keys
    end
  end
end
