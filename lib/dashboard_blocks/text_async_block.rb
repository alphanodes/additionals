# frozen_string_literal: true

module DashboardBlocks
  class TextAsyncBlock < Base
    block_id 'text_async'
    label :label_text_async
    max_occurs DashboardContent::MAX_MULTIPLE_OCCURS
    async required_settings: %i[text], partial: 'dashboards/blocks/text_async'
    setting :title, **DashboardContent::TITLE_SETTING
    setting :text, type: :text, label: :label_text_sync
  end
end
