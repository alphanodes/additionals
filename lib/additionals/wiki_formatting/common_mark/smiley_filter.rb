# frozen_string_literal: true

begin
  require 'html/pipeline' unless defined?(HTML::Pipeline)
rescue LoadError
  # HTML::Pipeline is optional on Redmine master where scrubbers are used instead.
end

module Additionals
  module WikiFormatting
    module CommonMark
      if defined?(HTML::Pipeline::Filter)
        class SmileyFilter < HTML::Pipeline::Filter
          include Additionals::Formatter

          def call
            ignore_ancestor_tags = %w[pre code].to_set
            doc.xpath('descendant-or-self::text()').each do |node|
              content = node.to_html
              next if has_ancestor? node, ignore_ancestor_tags

              html = render_inline_smileys content
              next if html == content

              node.replace html
            end
            doc
          end
        end
      else
        # TODO: Drop this stub once we no longer support Redmine versions that rely on HTML::Pipeline (pre Redmine 7).
        class SmileyFilter
          def initialize(*)
            raise NotImplementedError, 'HTML::Pipeline::Filter is not available'
          end
        end
      end
    end
  end
end
