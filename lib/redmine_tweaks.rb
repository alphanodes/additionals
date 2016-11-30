# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2016 AlphaNodes GmbH

if ActiveRecord::Base.connection.table_exists?(:settings)
  Rails.configuration.to_prepare do
    # Patches
    require_dependency 'redmine_tweaks/patches/custom_help_url'
    require_dependency 'redmine_tweaks/patches/issue_patch'
    require_dependency 'redmine_tweaks/patches/wiki_patch'
    require_dependency 'redmine_tweaks/patches/wiki_controller_patch'

    # Global helpers for Tweaks
    require_dependency 'redmine_tweaks/helpers'

    # Hooks
    require_dependency 'redmine_tweaks/hooks'

    # Wiki macros
    require_dependency 'redmine_tweaks/wiki_macros/calendar'
    require_dependency 'redmine_tweaks/wiki_macros/date'
    require_dependency 'redmine_tweaks/wiki_macros/gist'
    require_dependency 'redmine_tweaks/wiki_macros/issue_macro'
    require_dependency 'redmine_tweaks/wiki_macros/last_updated_at'
    require_dependency 'redmine_tweaks/wiki_macros/last_updated_by'
    require_dependency 'redmine_tweaks/wiki_macros/member_macro'
    require_dependency 'redmine_tweaks/wiki_macros/project_macro'
    require_dependency 'redmine_tweaks/wiki_macros/recently_updated'
    require_dependency 'redmine_tweaks/wiki_macros/slideshare'
    require_dependency 'redmine_tweaks/wiki_macros/twitter'
    require_dependency 'redmine_tweaks/wiki_macros/user_macro'
    require_dependency 'redmine_tweaks/wiki_macros/vimeo'
    require_dependency 'redmine_tweaks/wiki_macros/youtube'

    unless RedmineTweaks.settings[:remove_help]
      Redmine::Plugin.find('redmine_tweaks')
                     .menu :top_menu,
                           :help,
                           RedmineTweaks::Patches::CustomHelpUrl::Redmine::Info.help_url,
                           html: { target: '_blank' },
                           last: true
    end
  end

  # include deface overwrites
  Rails.application.paths['app/overrides'] ||= []
  tweaks_overwrite_dir = "#{Redmine::Plugin.directory}/redmine_tweaks/app/overrides".freeze
  unless Rails.application.paths['app/overrides'].include?(tweaks_overwrite_dir)
    Rails.application.paths['app/overrides'] << tweaks_overwrite_dir
  end
end
