# -*- encoding : utf-8 -*-
require 'redmine'

Redmine::Plugin.register :redmine_tweaks do
  name 'Redmine Tweaks'
  author 'AlphaNodes GmbH'
  description 'Wiki and content extensions'
  version '0.5.3'
  author_url 'https://alphanodes.com/'
  url 'https://github.com/alexandermeindl/redmine_tweaks'

  default_settings = {
    'external_urls' => '0',
    'custom_help_url' => 'http://www.redmine.org/guide',
    'remove_help' => false,
    'add_go_to_top' => false,
    'remove_mypage' => false,
    'disabled_modules' => nil,
    'account_login_bottom' => '',
    'overview_text_title' => '',
    'overview_text' => '',
    'new_ticket_message' => 'Don\'t forget to define acceptance criteria!',
    'project_wiki_skeletal_title' => 'Project guide',
    'project_wiki_skeletal' => 'Go to admin area and define a nice wiki text here as a fixed skeletal for all projects.',
    'global_sidebar' => '',
    'global_wiki_sidebar' => '',
    'global_wiki_header' => '',
    'global_wiki_footer' => '',
    'global_footer' => ''
  }

  permission :hide_in_memberbox, {}
  permission :show_hidden_roles_in_memberbox, {}

  project_module :issue_tracking do
    permission :edit_closed_issues, {}
  end

  5.times do |i|
    default_settings['custom_menu'+i.to_s+'_name'] = '';
    default_settings['custom_menu'+i.to_s+'_url'] = '';
    default_settings['custom_menu'+i.to_s+'_title'] = '';
  end

  settings(:default => default_settings, :partial => 'settings/redmine_tweaks')

  # required redmine version
  requires_redmine :version_or_higher => '2.4.6'

  # remove help menu (it will be added later again)
  delete_menu_item(:top_menu, :help)

  # remove my page
  delete_menu_item(:top_menu, :my_page)
  menu :top_menu, :my_page, { :controller => 'my', :action => 'page'}, :via => :get,
   :if => Proc.new{User.current && !RedmineTweaks.settings[:remove_mypage] }

  RedCloth3::ALLOWED_TAGS << "div"
end

ActionDispatch::Callbacks.to_prepare do
  require_dependency 'redmine_tweaks/hooks'
  require_dependency 'redmine_tweaks/custom_help_url'
  require_dependency 'redmine_tweaks/project_macros'
  require_dependency 'redmine_tweaks/user_macros'
  require_dependency 'redmine_tweaks/date_macros'
  require_dependency 'redmine_tweaks/garfield_macros'
  require_dependency 'redmine_tweaks/youtube_macros'
end

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
    unless RedmineTweaks.settings[:remove_help]
	    Redmine::Plugin.find('redmine_tweaks').menu :top_menu, :help, RedmineTweaks::CustomHelpUrl::Redmine::Info.help_url, :html => {:target => '_blank'}, :last => true
    end

    Issue.send(:include, RedmineTweaks::IssuePatch) unless Issue.include?(RedmineTweaks::IssuePatch)

    unless Wiki.included_modules.include? RedmineTweaks::WikiPatch
      Wiki.send(:include, RedmineTweaks::WikiPatch)
    end

    unless WikiController.included_modules.include? RedmineTweaks::WikiControllerPatch
      WikiController.send(:include, RedmineTweaks::WikiControllerPatch)
    end
  end

  require 'settings_helper'
  SettingsHelper.send :include, RedmineTweaksHelper
end

