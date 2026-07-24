# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Downstream plugins render the shared mailer/_entity partial for their own
# journalized entities. Some of those entities (e.g. redmine_templates'
# TemplateProject) have no attachments association and therefore render the
# partial with `with_attachments: false`. In that case the partial must not
# touch #attachments at all - otherwise it crashes with NoMethodError.
class MailerEntityPartialTest < Additionals::HelperTest
  # A minimal downstream-style entity WITHOUT an attachments association.
  class AttachmentlessEntity
    def self.name = 'attachmentless_entity'
    def description = 'Body text of the attachment-less entity'
  end

  # Downstream plugins provide an email_<class>_attributes helper for their
  # entity; supply the matching one so render_email_attributes resolves.
  module AttachmentlessEntityHelper
    def email_attachmentless_entity_attributes(entry, _html)
      ["Name: #{entry.description}"]
    end
  end

  helper AdditionalsJournalsHelper
  helper Additionals::Helpers
  helper AttachmentlessEntityHelper

  def test_text_partial_does_not_touch_attachments_when_disabled
    entity = AttachmentlessEntity.new

    body = render partial: 'mailer/entity',
                  formats: [:text],
                  locals: { title: 'Attachment-less Entity',
                            entity_url: 'http://example.net/entity/1',
                            entity:,
                            content_field: :description,
                            with_attachments: false }

    assert_includes body, entity.description
    assert_not_includes body, l(:label_attachment_plural)
  end
end
