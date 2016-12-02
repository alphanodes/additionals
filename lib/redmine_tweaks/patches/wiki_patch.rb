# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2016 AlphaNodes GmbH

require_dependency 'wiki'

module RedmineTweaks
  module Patches
    # Patch wiki to include sidebar
    module WikiPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethodsForRedmineTweaksWiki)
        base.class_eval do
          alias_method_chain :sidebar, :redmine_tweaks
        end
      end
    end

    # Instance methodes for Wiki
    module InstanceMethodsForRedmineTweaksWiki
      def sidebar_with_redmine_tweaks
        @sidebar ||= find_page('Sidebar', with_redirect: false)
        if @sidebar && @sidebar.content
          sidebar_without_redmine_tweaks
        else
          wiki_sidebar = '' + Setting.plugin_redmine_tweaks[:global_wiki_sidebar].to_s
          @sidebar ||= find_page('Wiki', with_redirect: false)
          if wiki_sidebar != '' && @sidebar.try(:content)
            @sidebar.content.text = wiki_sidebar
          end
        end
      end
    end
  end
end

unless Wiki.included_modules.include? RedmineTweaks::Patches::WikiPatch
  Wiki.send(:include, RedmineTweaks::Patches::WikiPatch)
end
