# frozen_string_literal: true

# The number of attached files, next to core's file LIST: in a list the file
# names are a wall of text, while the count answers what is actually being
# asked - is there anything attached and how much.
class QueryAttachmentsCountColumn < QueryColumn
  def initialize(queried_class)
    # Own caption on purpose, because core's file list is already named
    # "Files" and two identically named entries in the column selection are
    # indistinguishable.
    super :attachments_count,
          caption: :field_attachments_count,
          sortable: order_sql(queried_class),
          default_order: 'desc'
  end

  def order_sql(queried_class)
    <<~SQL.squish
      COALESCE((SELECT COUNT(*) FROM #{Attachment.table_name}
      WHERE #{Attachment.table_name}.container_type='#{queried_class.base_class.name}'
      AND #{Attachment.table_name}.container_id=#{queried_class.table_name}.id), 0)
    SQL
  end
end
