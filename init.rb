raise "\n\033[31madditionals requires ruby 2.4 or newer. Please update your ruby version.\033[0m" if RUBY_VERSION < '2.4'

Redmine::Plugin.register :additionals do
  name 'Additionals'
  author 'AlphaNodes GmbH'
  description 'Customizing Redmine, providing wiki macros and act as a library/function provider for other Redmine plugins'
  version '2.0.24'
  author_url 'https://alphanodes.com/'
  url 'https://github.com/alphanodes/additionals'

  default_settings = Additionals.load_settings
  5.times do |i|
    default_settings['custom_menu' + i.to_s + '_name'] = ''
    default_settings['custom_menu' + i.to_s + '_url'] = ''
    default_settings['custom_menu' + i.to_s + '_title'] = ''
  end

  settings(default: default_settings, partial: 'additionals/settings/additionals')

  permission :show_hidden_roles_in_memberbox, {}

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
  requires_redmine version_or_higher: '4.0.0'

  menu :admin_menu, :additionals, { controller: 'settings', action: 'plugin', id: 'additionals' }, caption: :label_additionals

  RedCloth3::ALLOWED_TAGS << 'div'
end

Rails.configuration.to_prepare do
  Additionals.setup
end

Rails.application.config.after_initialize do
  FONTAWESOME_ICONS = { fab: AdditionalsFontAwesome.load_icons(:fab),
                        far: AdditionalsFontAwesome.load_icons(:far),
                        fas: AdditionalsFontAwesome.load_icons(:fas) }.freeze
end

Rails.application.paths['app/overrides'] ||= []
Dir.glob(Rails.root.join('plugins/*/app/overrides')).each do |dir|
  Rails.application.paths['app/overrides'] << dir unless Rails.application.paths['app/overrides'].include?(dir)
end
