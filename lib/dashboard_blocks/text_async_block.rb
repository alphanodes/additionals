# frozen_string_literal: true

module DashboardBlocks
  class TextAsyncBlock < Base
    block_id 'text_async'
    label :label_text_async
    max_occurs DashboardContent::MAX_MULTIPLE_OCCURS
    async required_settings: %i[text], partial: 'dashboards/blocks/text_async'
    settings_partial 'dashboards/blocks/text_async_settings'
    setting :title, **DashboardContent::TITLE_SETTING
    setting :text, type: :text, label: :label_text_sync

    # The text as written, its formatting is up to the reader
    def export_data
      { title:, text: }
    end
  end
end
