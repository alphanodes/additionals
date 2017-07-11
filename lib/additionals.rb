if ActiveRecord::Base.connection.table_exists?(:settings)
  Rails.configuration.to_prepare do
    if Redmine::Plugin.installed?('redmine_tweaks')
      raise "\n\033[31madditionals plugin cannot be used with redmine_tweaks plugin'.\033[0m"
    end

    if Redmine::Plugin.installed?('common_libraries')
      raise "\n\033[31madditionals plugin cannot be used with common_libraries plugin'.\033[0m"
    end

    # Patches
    # require_dependency 'additionals/patches/custom_help_url'
    require_dependency 'additionals/patches/issue_patch'
    require_dependency 'additionals/patches/time_entry_patch'
    require_dependency 'additionals/patches/wiki_patch'
    require_dependency 'additionals/patches/wiki_controller_patch'
    require_dependency 'additionals/patches/wiki_pdf_helper_patch'
    require 'additionals/patches/application_controller_patch'

    Rails.configuration.assets.paths << Emoji.images_path
    # Send Emoji Patches to all wiki formatters available to be able to switch formatter without app restart
    Redmine::WikiFormatting.format_names.each do |format|
      case format
      when 'markdown'
        require_dependency 'additionals/patches/formatter_markdown_patch'
      when 'textile'
        require_dependency 'additionals/patches/formatter_textile_patch'
      end
    end

    # Global helpers
    require_dependency 'additionals/helpers'

    # Hooks
    require_dependency 'additionals/hooks'

    # Wiki macros
    require_dependency 'additionals/wiki_macros/calendar'
    require_dependency 'additionals/wiki_macros/cryptocompare'
    require_dependency 'additionals/wiki_macros/date'
    require_dependency 'additionals/wiki_macros/gist'
    require_dependency 'additionals/wiki_macros/issue_macro'
    require_dependency 'additionals/wiki_macros/last_updated_at'
    require_dependency 'additionals/wiki_macros/last_updated_by'
    require_dependency 'additionals/wiki_macros/member_macro'
    require_dependency 'additionals/wiki_macros/project_macro'
    require_dependency 'additionals/wiki_macros/recently_updated'
    require_dependency 'additionals/wiki_macros/reddit'
    require_dependency 'additionals/wiki_macros/slideshare'
    require_dependency 'additionals/wiki_macros/tradingview'
    require_dependency 'additionals/wiki_macros/twitter'
    require_dependency 'additionals/wiki_macros/user_macro'
    require_dependency 'additionals/wiki_macros/vimeo'
    require_dependency 'additionals/wiki_macros/youtube'

    module Additionals
      def self.settings
        Setting[:plugin_additionals].blank? ? {} : Setting[:plugin_additionals]
      end
    end
  end

  # include deface overwrites
  Rails.application.paths['app/overrides'] ||= []
  additionals_overwrite_dir = "#{Redmine::Plugin.directory}/additionals/app/overrides".freeze
  unless Rails.application.paths['app/overrides'].include?(additionals_overwrite_dir)
    Rails.application.paths['app/overrides'] << additionals_overwrite_dir
  end
end
