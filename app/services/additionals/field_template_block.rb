# frozen_string_literal: true

module Additionals
  # Finds the template a wiki page keeps for a list macro: the one code block
  # whose language is the name of the macro. The rest of the page explains the
  # template and is never part of it.
  #
  # Read in the text format of the wiki, because only there is the block a
  # code block: a fence in CommonMark, <pre><code class="..."> in Textile.
  class FieldTemplateBlock
    COMMON_MARK = 'common_mark'
    # An opening fence of three or more backticks or tildes, indented by up
    # to three spaces, followed by its info string
    FENCE_RE = /\A( {0,3})(`{3,}|~{3,})(.*)\z/
    TEXTILE_RE = %r{<pre>\s*<code\s+class=(["'])([^"']*)\1\s*>(.*?)</code>\s*</pre>}m

    class << self
      # The template of the block, or nil where the text has none. A second
      # block is an error: which one is meant could only be guessed.
      def find(text, language)
        blocks = Setting.text_formatting == COMMON_MARK ? fenced_blocks(text) : textile_blocks(text)
        blocks = blocks.filter_map { |info, content| content if info.casecmp? language }
        raise FieldTemplate::Error.new(:error_field_template_block_ambiguous, language:) if blocks.many?

        blocks.first&.strip
      end

      private

      # Pairs of the language and the content of every fenced block. A fence
      # is closed by one of the same character and at least the same length;
      # an unclosed one runs to the end of the text. The indentation of an
      # indented fence is removed from its lines, both as in CommonMark.
      def fenced_blocks(text)
        blocks = []
        fence = nil
        indent = nil
        text.to_s.each_line do |line|
          if fence.nil?
            match = FENCE_RE.match line.chomp
            next if match.nil? || (match[2].start_with?('`') && match[3].include?('`'))

            indent, fence = match.captures
            blocks << [match[3].strip.split.first.to_s, +'']
          elsif closing_fence? line, fence
            fence = nil
          else
            blocks.last.last << line.sub(/\A {0,#{indent.length}}/, '')
          end
        end

        blocks
      end

      def closing_fence?(line, fence)
        line.chomp.match?(/\A {0,3}#{Regexp.escape fence[0]}{#{fence.length},}[ \t]*\z/)
      end

      def textile_blocks(text)
        text.to_s.scan(TEXTILE_RE).map { |_quote, info, content| [info.strip, content] }
      end
    end
  end
end
