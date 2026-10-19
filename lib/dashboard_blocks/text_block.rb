# frozen_string_literal: true

module DashboardBlocks
  # Without a text the block shows a hint, so it is no required setting
  class TextBlock < Base
    block_id 'text'
    label :label_text_sync
    max_occurs DashboardContent::MAX_MULTIPLE_OCCURS
    partial 'dashboards/blocks/text'
    settings_partial 'dashboards/blocks/text_async_settings'
    setting :title, **DashboardContent::TITLE_SETTING
    setting :text, type: :text, label: :label_text_sync

    # The text as written, its formatting is up to the reader
    def export_data
      { title:, text: }
    end
  end
end
