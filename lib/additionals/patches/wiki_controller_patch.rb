require_dependency 'wiki_controller'

module Additionals
  module Patches
    module WikiControllerPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        alias_method :respond_to_without_additionals, :respond_to
        alias_method :respond_to, :respond_to_with_additionals
      end

      module InstanceMethods
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
          wiki_header = '' + Additionals.setting(:global_wiki_header).to_s
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
          wiki_footer = '' + Additionals.setting(:global_wiki_footer).to_s
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
end
