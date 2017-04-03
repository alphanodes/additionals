# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

require 'redmine'
require 'redmine_tweaks'

Redmine::Plugin.register :redmine_tweaks do
  name 'Tweaks'
  author 'AlphaNodes GmbH'
  description 'Wiki and content extensions'
  version '1.0.1'
  author_url 'https://alphanodes.com/'
  url 'https://github.com/alphanodes/redmine_tweaks'

  default_settings = {
    account_login_bottom: '',
    add_go_to_top: 0,
    custom_help_url: 'http://www.redmine.org/guide',
    disabled_modules: nil,
    external_urls: 0,
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

  settings(default: default_settings, partial: 'settings/redmine_tweaks/redmine_tweaks')

  permission :hide_in_memberbox, {}
  permission :show_hidden_roles_in_memberbox, {}

  project_module :issue_tracking do
    permission :edit_closed_issues, {}
  end

  project_module :time_tracking do
    permission :log_time_on_closed_issues, {}
  end

  # required redmine version
  requires_redmine version_or_higher: '2.6.0'

  # remove help menu (it will be added later again)
  delete_menu_item(:top_menu, :help)

  # remove my page
  delete_menu_item(:top_menu, :my_page)
  menu :top_menu,
       :my_page,
       { controller: 'my', action: 'page' },
       via: :get,
       if: proc { User.current.logged? && !RedmineTweaks.settings[:remove_mypage] }

  menu :admin_menu, :tweaks, { controller: 'settings', action: 'plugin', id: 'redmine_tweaks' }, caption: :label_tweaks

  RedCloth3::ALLOWED_TAGS << 'div'
end
