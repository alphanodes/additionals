require_dependency 'wiki'

module Additionals
  module Patches
    # Patch wiki to include sidebar
    module WikiPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethodsForAdditionalsWiki)
        base.class_eval do
          alias_method_chain :sidebar, :additionals
        end
      end
    end

    # Instance methodes for Wiki
    module InstanceMethodsForAdditionalsWiki
      def sidebar_with_additionals
        @sidebar ||= find_page('Sidebar', with_redirect: false)
        if @sidebar && @sidebar.content
          sidebar_without_additionals
        else
          wiki_sidebar = '' + Additionals.settings[:global_wiki_sidebar].to_s
          @sidebar ||= find_page('Wiki', with_redirect: false)
          if wiki_sidebar != '' && @sidebar.try(:content)
            @sidebar.content.text = wiki_sidebar
          end
        end
      end
    end
  end
end
