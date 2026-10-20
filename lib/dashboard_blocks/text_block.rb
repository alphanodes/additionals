# frozen_string_literal: true

module DashboardBlocks
  # Without a text the settings form of a new block is open, like that of
  # text_async
  class TextBlock < Base
    block_id 'text'
    label :label_text_sync
    max_occurs DashboardContent::MAX_MULTIPLE_OCCURS
    partial 'dashboards/blocks/text'
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
