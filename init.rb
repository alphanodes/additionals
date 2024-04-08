# frozen_string_literal: true

require 'additionals/plugin_version'

loader = RedminePluginKit::Loader.new plugin_id: 'additionals'

Redmine::Plugin.register :additionals do
  name 'Additionals'
  author 'AlphaNodes GmbH'
  description 'Customizing Redmine, providing dashboards, wiki macros and other functions for better usability.' \
              ' As well as acting as a library/function provider for other Redmine plugins'
  version Additionals::PluginVersion::VERSION
  author_url 'https://alphanodes.com/'
  url 'https://github.com/alphanodes/additionals'
  directory File.dirname(__FILE__)

  settings default: loader.default_settings,
           partial: 'additionals/settings/additionals'

  permission :show_hidden_roles_in_memberbox, {}
  permission :set_system_dashboards,
             {},
             require: :loggedin,
             read: true
  permission :share_dashboards,
             { dashboards: %i[index new create edit update destroy] },
             require: :member,
             read: true
  permission :save_dashboards,
             { dashboards: %i[index new create edit update destroy] },
             require: :loggedin,
             read: true

  project_module :issue_tracking do
    permission :edit_closed_issues, {}
    permission :edit_issue_author, {}
    permission :change_new_issue_author, {}
    permission :issue_timelog_never_required, {}
  end

  project_module :time_tracking do
    permission :log_time_on_closed_issues, {}
  end

  # required redmine version
  requires_redmine version_or_higher: '5.0'

  menu :admin_menu, :additionals, { controller: 'settings', action: 'plugin', id: 'additionals' }, caption: :label_additionals
end

RedminePluginKit::Loader.persisting do
  Redmine::AccessControl.include Additionals::Patches::AccessControlPatch
  Redmine::AccessControl.singleton_class.prepend Additionals::Patches::AccessControlClassPatch

  # Hooks
  loader.load_model_hooks!
end

RedminePluginKit::Loader.after_initialize do
  unless defined? FONTAWESOME_ICONS
    # @TODO: this should be moved to AdditionalsFontAwesome and use an instance of it
    FONTAWESOME_ICONS = { fab: AdditionalsFontAwesome.load_icons(:fab),
                          far: AdditionalsFontAwesome.load_icons(:far),
                          fas: AdditionalsFontAwesome.load_icons(:fas) }.freeze
  end
end
