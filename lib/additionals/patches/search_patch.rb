# frozen_string_literal: true

module Additionals
  module Patches
    module SearchPatch
      # Mapping of search types to project modules.
      # Search types not listed here are always available.
      SEARCH_TYPE_MODULES = {
        'issues' => :issue_tracking,
        'news' => :news,
        'documents' => :documents,
        'changesets' => :repository,
        'wiki_pages' => :wiki,
        'messages' => :boards
      }.freeze

      def available_search_types
        disabled = Redmine::AccessControl.disabled_project_modules
        return super if disabled.blank?

        super.reject do |type|
          mod = SEARCH_TYPE_MODULES[type]
          mod && disabled.include?(mod)
        end
      end
    end
  end
end
