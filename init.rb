# -*- encoding : utf-8 -*-
require 'redmine'

require 'dispatcher' unless Rails::VERSION::MAJOR >= 3
require_dependency 'redmine_tweaks/hooks'
require_dependency 'redmine_tweaks/project_macros'
require_dependency 'redmine_tweaks/user_macros'
require_dependency 'redmine_tweaks/date_macros'

Rails.configuration.to_prepare do

  Issue.send(:include, RedmineTweaks::IssuePatch) unless Issue.include?(RedmineTweaks::IssuePatch)

  unless Wiki.included_modules.include? RedmineTweaks::WikiPatch
    Wiki.send(:include, RedmineTweaks::WikiPatch)
  end

  unless WikiController.included_modules.include? RedmineTweaks::WikiControllerPatch
    WikiController.send(:include, RedmineTweaks::WikiControllerPatch)
  end

end

Redmine::Plugin.register :redmine_tweaks do
  name 'Redmine Tweaks'
  author 'AlphaNodes GmbH'
  description 'Wiki and content extensions'
  version '0.4.0'
  author_url 'http://alphanodes.com/'
  url 'http://github.com/alexandermeindl/redmine_tweaks'

  default_settings = {
    'external_urls' => '0',
    'custom_help_url' => 'http://www.redmine-buch.de',
    'show_task_board_link' => false,
    'remove_mypage' => false,
    'disabled_modules' => nil,
    'account_login_bottom' => '',
    'new_ticket_message' => 'Don\'t forget to define acceptance criteria!',
    'project_wiki_skeletal' => 'Go to admin area and define a nice wiki text here as a fixed skeletal for all projects.',
    'global_sidebar' => '',
    'global_wiki_sidebar' => '',
    'global_wiki_header' => '',
    'global_wiki_footer' => ''
  }
  settings(:default => default_settings, :partial => 'settings/redmine_tweaks')

  # required redmine version
  requires_redmine :version_or_higher => '2.3.3'
  
  # Add Task board
  menu :top_menu, :task_board, { :controller => 'wiki', :action => 'show', :id => 'Task_board', :project_id => 'common' },
    :if => Proc.new{User.current.allowed_to?({:controller => 'wiki', :action => 'show', :id => 'Task_board', :project_id => 'common'}, nil, {:global => true}) && RedmineTweaks.settings[:show_task_board_link] }

  # remove help menu (it will be added later again)
  delete_menu_item(:top_menu, :help)

  # remove my page
  delete_menu_item(:top_menu, :my_page)
  menu :top_menu, :my_page, { :controller => 'my', :action => 'page'}, :via => :get,
   :if => Proc.new{User.current.allowed_to?({:controller => 'my', :action => 'page'}, nil, {:global => true}) && !RedmineTweaks.settings[:remove_mypage] }  
  
end

if Rails::VERSION::MAJOR >= 3
  ActionDispatch::Callbacks.to_prepare do
    require_dependency 'redmine_tweaks/custom_help_url'
  end
else
  Dispatcher.to_prepare do
    require_dependency 'redmine_tweaks/custom_help_url'
  end
end

# Workaround inability to access Setting.plugin_name['setting'], both directly as well as via overridden
# module containing the call to Setting.*, before completed plugin registration since we use a call to either:
# * Setting.plugin_redmine_custom_help_url['custom_help_url'] or (and replaced by)
# * RedmineCustomHelpUrl::Redmine::Info.help_url,
# which both can *only* be accessed *after* completed plugin registration (http://www.redmine.org/issues/7104)
#
# We now use overridden module RedmineCustomHelpUrl::Redmine::Info instead of directly calling 
# Setting.plugin_redmine_custom_help_url['custom_help_url']
Redmine::Plugin.find('redmine_tweaks').menu :top_menu, :help, RedmineTweaks::CustomHelpUrl::Redmine::Info.help_url, :last => true

require 'settings_helper'
SettingsHelper.send :include, RedmineTweaksHelper