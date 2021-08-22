# frozen_string_literal: true

module AdditionalsWikiPdfHelper
  include Redmine::Export::PDF

  def wiki_page_to_pdf(page, project)
    pdf = ITCPDF.new current_language
    pdf.set_title "#{project} - #{page.title}"
    pdf.alias_nb_pages
    pdf.footer_date = format_date User.current.today
    pdf.add_page
    unless Additionals.setting? :wiki_pdf_remove_title
      pdf.SetFontStyle 'B', 11
      pdf.RDMMultiCell(190, 5,
                       "#{project} - #{page.title} - # #{page.content.version}")
    end
    pdf.ln
    # Set resize image scale
    pdf.set_image_scale 1.6
    pdf.SetFontStyle '', 9
    if Additionals.setting? :wiki_pdf_remove_attachments
      pdf.RDMwriteFormattedCell(190,
                                5,
                                '',
                                '',
                                textilizable(page.content,
                                             :text,
                                             only_path: false,
                                             edit_section_links: false,
                                             headings: false,
                                             inline_attachments: false), page.attachments)
    else
      write_wiki_page pdf, page
    end
    pdf.output
  end
end
