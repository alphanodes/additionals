module Additionals
  module Patches
    module WikiPatch
      def self.included(base)
        # no need to do this more than once.
        return if Wiki < InstanceMethods
        base.class_eval do
          prepend InstanceMethods
        end
      end
    end

    module InstanceMethods
      def sidebar
        @sidebar ||= find_page('Sidebar', with_redirect: false)
        if @sidebar && @sidebar.content
          super
        else
          wiki_sidebar = '' + Additionals.settings[:global_wiki_sidebar].to_s
          @sidebar ||= find_page('Wiki', with_redirect: false)
          @sidebar.content.text = wiki_sidebar if wiki_sidebar != '' && @sidebar.try(:content)
        end
      end
    end
  end
end
