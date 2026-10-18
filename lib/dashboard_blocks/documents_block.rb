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

    # The latest documents of the project, of all projects without one
    def data
      @data ||= begin
        scope = Document.visible user
        scope = scope.where project: project if project
        scope.order(created_on: :desc).limit(max_entries).includes(:project, :category).to_a
      end
    end

    def export_data
      data.map do |document|
        { id: document.id, title: document.title, project: document.project.name,
          category: document.category&.name, created_on: document.created_on.iso8601 }
      end
    end
  end
end
