# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013  AlphaNodes GmbH

begin
  require_dependency 'application'
rescue LoadError
end
require_dependency 'wiki'

module RedmineTweaks
  
  module WikiPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethodsForRedmineTweaksWiki)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        alias_method_chain :sidebar, :redmine_tweaks
      end
    end
  end

  module InstanceMethodsForRedmineTweaksWiki

    def sidebar_with_redmine_tweaks
      @sidebar ||= find_page('Sidebar', :with_redirect => false)
      unless @sidebar && @sidebar.content
        wiki_sidebar = '' + Setting.plugin_redmine_tweaks['global_wiki_sidebar']
        @sidebar ||= find_page('Wiki', :with_redirect => false)
        if !wiki_sidebar.nil?
          @sidebar ||= find_page('Wiki', :with_redirect => false)
          @sidebar.content.text = wiki_sidebar;
        end
      else
        sidebar_without_redmine_tweaks  
      end
    end
  end
  
end
