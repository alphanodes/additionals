require_dependency 'wiki_controller'

module Additionals
  module Patches
    module WikiControllerPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethodsForAdditionalsWikiController)
        base.class_eval do
          alias_method_chain :respond_to, :additionals
        end
      end
    end

    module InstanceMethodsForAdditionalsWikiController
      def respond_to_with_additionals(&block)
        if @project && @content
          if @_action_name == 'show'
            additionals_include_header
            additionals_include_footer
          end
        end
        respond_to_without_additionals(&block)
      end

      private

      def additionals_include_header
        wiki_header = '' + Additionals.settings[:global_wiki_header].to_s
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

      def additionals_include_footer
        wiki_footer = '' + Additionals.settings[:global_wiki_footer].to_s
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
