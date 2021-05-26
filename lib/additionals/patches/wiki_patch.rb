# frozen_string_literal: true

require_dependency 'wiki'

module Additionals
  module Patches
    # Patch wiki to include sidebar
    module WikiPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        alias_method :sidebar_without_additionals, :sidebar
        alias_method :sidebar, :sidebar_with_additionals
      end

      class_methods do
        def join_enabled_module
          "JOIN #{EnabledModule.table_name} ON #{EnabledModule.table_name}.project_id=#{Wiki.table_name}.project_id" \
          " AND #{EnabledModule.table_name}.name='wiki'"
        end
      end

      module InstanceMethods
        def sidebar_with_additionals
          @sidebar ||= find_page 'Sidebar', with_redirect: false
          if @sidebar&.content
            sidebar_without_additionals
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
