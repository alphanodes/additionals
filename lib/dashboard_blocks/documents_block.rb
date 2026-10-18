# frozen_string_literal: true

module DashboardBlocks
  class DocumentsBlock < Base
    block_id 'documents'
    label :label_document_plural
    permission :view_documents
    setting :max_entries, **DashboardContent::MAX_ENTRIES_SETTING, max: 1000

    def available?
      Redmine::AccessControl.active_module? :documents
    end
  end
end
