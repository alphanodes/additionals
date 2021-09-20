# frozen_string_literal: true

require_dependency 'wiki'

module Additionals
  module Patches
    # Patch wiki to include sidebar
    module WikiPatch
      extend ActiveSupport::Concern

      ENTITY_MODULE_NAME = 'wiki'

      included do
        include Additionals::EntityMethodsGlobal
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def sidebar
          @sidebar ||= find_page 'Sidebar', with_redirect: false
          if @sidebar&.content
            super
          else
            wiki_sidebar = Additionals.setting(:global_wiki_sidebar).to_s
            @sidebar ||= find_page project.wiki.start_page, with_redirect: false
            @sidebar.content.text = wiki_sidebar if wiki_sidebar != '' && @sidebar.try(:content)
          end
        end
      end
    end
  end
end
