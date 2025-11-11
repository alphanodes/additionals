# frozen_string_literal: true

module Additionals
  module WikiFormatting
    module CommonMark
      # Scrubber version for Redmine Master (7.0+) using Loofah
      class SmileyScrubber < Loofah::Scrubber
        include Additionals::Formatter

        def scrub(node)
          return unless node.text?
          return if ancestor? node, %w[pre code]

          content = node.text
          html = render_inline_smileys content
          return if html == content

          node.replace html
        end

        private

        # Optimized ancestor check with early exit pattern
        # See Redmine Core Issue #43446 for performance rationale
        def ancestor?(node, tags)
          parent = node.parent
          while parent
            return true if tags.include? parent.name

            parent = parent.parent
          end
          false
        end
      end
    end
  end
end
