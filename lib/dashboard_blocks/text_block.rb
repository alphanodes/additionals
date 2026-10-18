# frozen_string_literal: true

module DashboardBlocks
  # Without a text the block shows a hint, so it is no required setting
  class TextBlock < Base
    block_id 'text'
    label :label_text_sync
    max_occurs DashboardContent::MAX_MULTIPLE_OCCURS
    partial 'dashboards/blocks/text'
    setting :title, **DashboardContent::TITLE_SETTING
    setting :text, type: :text, label: :label_text_sync
  end
end
