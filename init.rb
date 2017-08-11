require 'redmine'
require 'additionals'

Redmine::Plugin.register :additionals do
  name 'Additionals'
  author 'AlphaNodes GmbH'
  description 'Customizing Redmine, providing wiki macros and act as a library/function provider for other Redmine plugins'
  version '2.0.3'
  author_url 'https://alphanodes.com/'
  url 'https://github.com/alphanodes/additionals'

  default_settings = Additionals.load_settings
  5.times do |i|
    default_settings['custom_menu' + i.to_s + '_name'] = ''
    default_settings['custom_menu' + i.to_s + '_url'] = ''
    default_settings['custom_menu' + i.to_s + '_title'] = ''
  end

  settings(default: default_settings, partial: 'additionals/settings/additionals')

  permission :hide_in_memberbox, {}
  permission :show_hidden_roles_in_memberbox, {}

  project_module :issue_tracking do
    permission :edit_closed_issues, {}
    permission :edit_issue_author, {}
    permission :change_new_issue_author, {}
  end

  project_module :time_tracking do
    permission :log_time_on_closed_issues, {}
  end

  # required redmine version
  requires_redmine version_or_higher: '3.0.0'

  menu :admin_menu, :additionals, { controller: 'settings', action: 'plugin', id: 'additionals' }, caption: :label_additionals

  RedCloth3::ALLOWED_TAGS << 'div'
end
