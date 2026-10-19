# frozen_string_literal: true

module DashboardBlocks
  class TextAsyncBlock < Base
    block_id 'text_async'
    label :label_text_async
    max_occurs DashboardContent::MAX_MULTIPLE_OCCURS
    async required_settings: %i[text], partial: 'dashboards/blocks/text_async'
    setting :title, **DashboardContent::TITLE_SETTING
    setting :text, type: :text, label: :label_text_sync, required: true, field: 'dashboards/settings/wiki_text'

    # The text as written, its formatting is up to the reader
    def export_data
      { title:, text: }
    end

    private

    # Without a title the block shows no heading, so there is nothing to suggest
    def title_placeholder(_schema)
      nil
    end
  end
end
