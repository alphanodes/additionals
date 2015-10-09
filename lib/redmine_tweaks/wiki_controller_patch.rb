# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015 AlphaNodes GmbH

begin
  require_dependency 'application'
rescue LoadError
end
require_dependency 'wiki_controller'

module RedmineTweaks
  module WikiControllerPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethodsForRedmineTweaksWikiController)
      base.class_eval do
        alias_method_chain :respond_to, :redmine_tweaks
      end
    end
  end

  module InstanceMethodsForRedmineTweaksWikiController
    def respond_to_with_redmine_tweaks(&block)
      if @project && @content
        if (@_action_name == 'show')
          redmine_tweaks_include_header
          redmine_tweaks_include_footer
        end
      end
      respond_to_without_redmine_tweaks(&block)
    end

    private

    def redmine_tweaks_include_header
      wiki_header = '' + Setting.plugin_redmine_tweaks['global_wiki_header']

      if Object.const_defined?('WikiExtensionsUtil') && WikiExtensionsUtil.is_enabled?(@project)
        header = @wiki.find_page('Header')
        if header
          return
        end
      end

      if wiki_header != ''
        text = "\n"
        text << '<div id="wiki_extentions_header">'
        text << "\n\n"
        text << wiki_header
        text << "\n\n</div>"
        text << "\n\n"
        text << @content.text
        @content.text = text
      end
    end

    def redmine_tweaks_include_footer
      wiki_footer = '' + Setting.plugin_redmine_tweaks['global_wiki_footer']

      if Object.const_defined?('WikiExtensionsUtil') && WikiExtensionsUtil.is_enabled?(@project)
        footer = @wiki.find_page('Footer')
        if footer
          return
        end
      end

      if wiki_footer != ''
        text = @content.text
        text << "\n"
        text << '<div id="wiki_extentions_footer">'
        text << "\n\n"
        text << wiki_footer
        text << "\n\n</div>"
      end
    end
  end
end
