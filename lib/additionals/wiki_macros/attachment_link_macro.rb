# frozen_string_literal: true

module Additionals
  module WikiMacros
    module AttachmentLinkMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Link to an attachment.

    The attachment is only linked if the current user can view it (i.e. its issue,
    wiki page, document etc.). Otherwise a "not available" hint is shown.

    Syntax:

      {{attachment_link(ID [, text=TEXT, download=BOOL])}}
      {{attachment_link(id=ID [, text=TEXT, download=BOOL])}}

    Parameters:

      :param int id: numeric id of the attachment (required)
      :param string text: link text (default is the filename of the attachment)
      :param bool download: link to the direct download instead of the attachment page (default false)

    Examples:

      {{attachment_link(1)}} or {{attachment_link(id=1)}}
      ...Link to the attachment with id 1

      {{attachment_link(1, text=Important file)}}
      ...Link to the attachment with id 1 with link text "Important file"

      {{attachment_link(1, download=true)}}
      ...Link to the direct download of the attachment with id 1
        DESCRIPTION

        macro :attachment_link do |_obj, args|
          args, options = extract_macro_options args, :text, :download, :id

          attachment_id = options[:id].presence || args&.first
          raise 'The correct usage is {{attachment_link(<attachment_id>)}}' unless attachment_id.to_s.match?(/\A\d+\z/)

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
