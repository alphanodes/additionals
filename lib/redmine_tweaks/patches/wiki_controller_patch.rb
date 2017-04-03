# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

require_dependency 'wiki_controller'

module RedmineTweaks
  module Patches
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
          if @_action_name == 'show'
            redmine_tweaks_include_header
            redmine_tweaks_include_footer
          end
        end
        respond_to_without_redmine_tweaks(&block)
      end

      private

      def redmine_tweaks_include_header
        wiki_header = '' + Setting.plugin_redmine_tweaks[:global_wiki_header].to_s
        return if wiki_header.empty?

        if Object.const_defined?('WikiExtensionsUtil') && WikiExtensionsUtil.is_enabled?(@project)
          header = @wiki.find_page('Header')
          return if header
        end

        text = "\n"
        text << '<div id="wiki_extentions_header">'
        text << "\n\n"
        text << wiki_header
        text << "\n\n</div>"
        text << "\n\n"
        text << @content.text
        @content.text = text
      end

      def redmine_tweaks_include_footer
        wiki_footer = '' + Setting.plugin_redmine_tweaks[:global_wiki_footer].to_s
        return if wiki_footer.empty?

        if Object.const_defined?('WikiExtensionsUtil') && WikiExtensionsUtil.is_enabled?(@project)
          footer = @wiki.find_page('Footer')
          return if footer
        end

        text = @content.text
        text << "\n\n"
        text << '<div id="wiki_extentions_footer">'
        text << "\n\n"
        text << wiki_footer
        text << "\n\n</div>"
      end
    end
  end
end

unless WikiController.included_modules.include? RedmineTweaks::Patches::WikiControllerPatch
  WikiController.send(:include, RedmineTweaks::Patches::WikiControllerPatch)
end
