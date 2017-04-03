# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

module RedmineTweaks
  module Patches
    module WikiPdfHelperPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :wiki_page_to_pdf, :tweaks
        end
      end

      module InstanceMethods
        include Redmine::Export::PDF

        def wiki_page_to_pdf_with_tweaks(page, project)
          pdf = ITCPDF.new(current_language)
          pdf.set_title("#{project} - #{page.title}")
          pdf.alias_nb_pages
          pdf.footer_date = format_date(User.current.today)
          pdf.add_page
          if RedmineTweaks.settings[:wiki_pdf_header].present?
            pdf.SetFontStyle('', 9)
            pdf.RDMwriteFormattedCell(100,
                                      5,
                                      '',
                                      '',
                                      textilizable(RedmineTweaks.settings[:wiki_pdf_header],
                                                   only_path: false,
                                                   edit_section_links: false,
                                                   headings: false,
                                                   inline_attachments: false))
          end
          if RedmineTweaks.settings[:wiki_pdf_remove_title].to_i != 1
            pdf.SetFontStyle('B', 11)
            pdf.RDMMultiCell(190, 5,
                             "#{project} - #{page.title} - # #{page.content.version}")
          end
          pdf.ln
          # Set resize image scale
          pdf.set_image_scale(1.6)
          pdf.SetFontStyle('', 9)
          if RedmineTweaks.settings[:wiki_pdf_remove_attachments].to_i == 1
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
            write_wiki_page(pdf, page)
          end
          pdf.output
        end
      end
    end
  end
end

unless Redmine::Export::PDF::WikiPdfHelper.included_modules.include? RedmineTweaks::Patches::WikiPdfHelperPatch
  Redmine::Export::PDF::WikiPdfHelper.send(:include, RedmineTweaks::Patches::WikiPdfHelperPatch)
end
