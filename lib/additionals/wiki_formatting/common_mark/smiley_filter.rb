# frozen_string_literal: true

module Additionals
  module WikiFormatting
    module CommonMark
      class SmileyFilter < HTML::Pipeline::Filter
        IGNORED_ANCESTOR_TAGS = %w[pre code].to_set

        include Additionals::Formatter

        def call
          doc.xpath('descendant-or-self::text()').each do |node|
            content = node.to_html
            next if has_ancestor? node, IGNORED_ANCESTOR_TAGS

            html = render_inline_smileys content
            next if html == content

            node.replace html
          end
          doc
        end
      end
    end
  end
end
