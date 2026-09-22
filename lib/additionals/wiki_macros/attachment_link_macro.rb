# frozen_string_literal: true

module Additionals
  module WikiMacros
    module AttachmentLinkMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Link to any attachment.

    Syntax:

      {{attachment_link(ID, [id=INT, text=Custom link name, download=BOOL])}}

    Parameters:

      :param int id: id of attachment (required)
      :param string text: alternativ link text (default is filename of attachment)
      :param bool download: true or false (if true, attachment is linked to direct download; default false)

    Examples:

      {{attachment_link(1)}} or {{attachment_link(id=1)}}
      ...Link to attachment of issue with attachment id 1

      {{attachment_link(1, name=Important file of other issue)}}
      ...Link to attachment of issue with attachment id 1 and use link name "Important file of other issue"

      {{attachment_link(1, download=TRUE)}}
      ...Link to attachment of issue with attachment id 1. Link to download file"
        DESCRIPTION

        macro :attachment_link do |_obj, args|
          args, options = extract_macro_options args, :text, :download, :id

          attachment_id = options[:id].presence || args&.first
          raise 'The correct usage is {{attachment_link(<attachment_id>)}}' if attachment_id.blank?

          attachment = Attachment.find_by id: attachment_id
          return macro_not_available :label_attachment unless attachment&.visible?

          attachment_options = { class: 'attachment-link' }
          attachment_options[:download] = true if options[:download]
          attachment_options[:text] = options[:text] if options[:text].present?

          link_to_attachment(attachment, **attachment_options)
        end
      end
    end
  end
end
