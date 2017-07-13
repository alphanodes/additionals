require 'redmine'
require 'additionals'

Redmine::Plugin.register :additionals do
  name 'Additionals'
  author 'AlphaNodes GmbH'
  description 'Customizing Redmine, providing wiki macros and act as a library/function provider for other Redmine plugins'
  version '2.0.1'
  author_url 'https://alphanodes.com/'
  url 'https://github.com/alphanodes/additionals'

  default_settings = {
    account_login_bottom: '',
    add_go_to_top: 0,
    custom_help_url: 'http://www.redmine.org/guide',
    disabled_modules: nil,
    external_urls: 1,
    global_footer: '',
    global_sidebar: '',
    wiki_pdf_header: '',
    wiki_pdf_remove_title: 0,
    wiki_pdf_remove_attachments: 0,
    global_wiki_footer: '',
    global_wiki_header: '',
    global_wiki_sidebar: '',
    issue_auto_assign_role: '',
    issue_auto_assign_status: '',
    issue_auto_assign: 0,
    legacy_smiley_support: 0,
    new_ticket_message: 'Don\'t forget to define acceptance criteria!',
    overview_bottom: '',
    overview_right: '',
    overview_top: '',
    project_overview_content: 'Go to admin area and define a nice wiki text here as a fixed skeletal for all projects.',
    remove_help: 0,
    remove_mypage: 0,
    remove_news: 0
  }

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
  end

  project_module :time_tracking do
    permission :log_time_on_closed_issues, {}
  end

  # required redmine version
  requires_redmine version_or_higher: '3.0.0'

  menu :admin_menu, :additionals, { controller: 'settings', action: 'plugin', id: 'additionals' }, caption: :label_additionals

  RedCloth3::ALLOWED_TAGS << 'div'
end
