require_dependency 'wiki'

module Additionals
  module Patches
    # Patch wiki to include sidebar
    module WikiPatch
      def self.included(base)
        base.send(:include, InstanceMethodsForAdditionalsWiki)
        base.class_eval do
          alias_method :sidebar_without_additionals, :sidebar
          alias_method :sidebar, :sidebar_with_additionals
        end
      end
    end

    # Instance methodes for Wiki
    module InstanceMethodsForAdditionalsWiki
      def sidebar_with_additionals
        @sidebar ||= find_page('Sidebar', with_redirect: false)
        if @sidebar&.content
          sidebar_without_additionals
        else
          wiki_sidebar = Additionals.settings[:global_wiki_sidebar].to_s
          @sidebar ||= find_page(project.wiki.start_page, with_redirect: false)
          @sidebar.content.text = wiki_sidebar if wiki_sidebar != '' && @sidebar.try(:content)
        end
      end
    end
  end
end
