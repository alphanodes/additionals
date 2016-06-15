# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2016 AlphaNodes GmbH

if ActiveRecord::Base.connection.table_exists?(:settings)
  # Workaround inability to access Setting.plugin_name['setting'], both directly as well as via overridden
  # module containing the call to Setting.*, before completed plugin registration since we use a call to either:
  # * Setting.plugin_redmine_custom_help_url['custom_help_url'] or (and replaced by)
  # * RedmineCustomHelpUrl::Redmine::Info.help_url,
  # which both can *only* be accessed *after* completed plugin registration (http://www.redmine.org/issues/7104)
  #
  # We now use overridden module RedmineCustomHelpUrl::Redmine::Info instead of directly calling
  # Setting.plugin_redmine_custom_help_url['custom_help_url']
  Rails.configuration.to_prepare do
    # Patches
    require_dependency 'redmine_tweaks/patches/custom_help_url'
    require_dependency 'redmine_tweaks/patches/issue_patch'
    require_dependency 'redmine_tweaks/patches/wiki_patch'
    require_dependency 'redmine_tweaks/patches/wiki_controller_patch'

    # Helper
    require_dependency 'redmine_tweaks/helpers/tweaks_helper'

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
end

# Little hack for deface in redmine:
# - redmine plugins are not railties nor engines, so deface overrides are not detected automatically
# - deface doesn't support direct loading anymore ; it unloads everything at boot so that reload in dev works
# - hack consists in adding "app/overrides" path of all plugins in Redmine's main #paths
Rails.application.paths['app/overrides'] ||= []
Dir.glob("#{Rails.root}/plugins/*/app/overrides").each do |dir|
  Rails.application.paths['app/overrides'] << dir unless Rails.application.paths['app/overrides'].include?(dir)
end
