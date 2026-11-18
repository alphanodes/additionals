# frozen_string_literal: true

require 'strscan'

module Additionals
  # Turns a template into a tree of nodes.
  #
  # The syntax knows three things: text, placeholders ({%...%}) and optional
  # parts in square brackets, which may be nested. What a placeholder name
  # means - a field, an attribute, a condition - is none of the parser's
  # business; it only says where one begins and ends. FieldTemplate decides the
  # rest.
  #
  # Unbalanced brackets are text, the way they were typed: a template is written
  # by hand and may well contain a bracket which is not meant as a part.
  class FieldTemplateParser
    PLACEHOLDER_RE = /\{%([^%]+)%\}/
    # a single brace is text, so a macro call like {{toc}} passes through
    # untouched - only "{%" announces a placeholder
    GROUP_OPEN = '['
    GROUP_CLOSE = ']'
    PLACEHOLDER_START_RE = /\{%/
    GROUP_OPEN_RE = /\[/
    GROUP_CLOSE_RE = /\]/
    # everything up to the next character which could start a token
    TEXT_RE = /[^\[\]{]*/
    # of the unreadable rest, this much goes into the message
    ERROR_EXCERPT = 32

    # A placeholder which calls a function: {%join(", ", A, B)%}. Which functions
    # exist and what they do is none of the parser's business either - it only
    # separates the name from its arguments, and a quoted argument from a name.
    FUNCTION_RE = /\A(\w+)\((.*)\)\z/m
    LITERAL_RE = /\A"(.*)"\z/m
    # a quoted argument is one piece, comma and all - the separator of a join is
    # ", " more often than not
    ARGUMENT_RE = /"[^"]*"|[^,]+/
    # what turns a pair of brackets into a markdown link instead of an optional
    # part: the round bracket of its target, right behind the closing one
    LINK_RE = /\(/

    Text = Struct.new :text
    Placeholder = Struct.new :name
    # source is what was typed, so a message can show it back
    Function = Struct.new :name, :arguments, :source
    Argument = Struct.new :value, :literal
    Group = Struct.new :children

    class << self
      def parse(template)
        new(template).parse
      end

      # The names in the order they appear, without building a tree and without
      # judging them. For a message which lists the fields a name is built from.
      def placeholder_names(template)
        template.to_s.scan(PLACEHOLDER_RE).flatten
      end
    end

    def initialize(template)
      @scanner = StringScanner.new template.to_s
      @stack = [[]]
    end

    def parse
      read_token until @scanner.eos?
      close_open_groups

      @stack.first
    end

    private

    def read_token
      if @scanner.scan PLACEHOLDER_RE
        add placeholder(@scanner[1])
      elsif @scanner.match? PLACEHOLDER_START_RE
        # it looks like a placeholder but cannot be read as one - a bracket
        # which is not closed, a "%" in the value - and would otherwise end up
        # in the line as it was typed
        raise FieldTemplate::Error.new(:error_field_template_placeholder_not_readable,
                                       name: @scanner.rest[0, ERROR_EXCERPT])
      elsif @scanner.scan GROUP_OPEN_RE
        @stack << []
      elsif @scanner.scan GROUP_CLOSE_RE
        close_group
      else
        add Text.new(read_text)
      end
    end

    # A name with brackets behind it is a function call, everything else is a
    # plain placeholder.
    def placeholder(name)
      match = FUNCTION_RE.match name.strip
      return Placeholder.new name if match.nil?

      Function.new match[1], arguments(match[2]), name
    end

    # Arguments are separated by commas, which is why a field whose name carries
    # one has to be addressed by its id here.
    def arguments(text)
      text.scan(ARGUMENT_RE).filter_map do |argument|
        argument = argument.strip
        next if argument.empty?

        literal = LITERAL_RE.match argument
        literal ? Argument.new(literal[1], true) : Argument.new(argument, false)
      end
    end

    # The first character is taken unconditionally, otherwise a "{" or a "["
    # which is text would be read forever.
    def read_text
      "#{@scanner.getch}#{@scanner.scan TEXT_RE}"
    end

    # Text which follows text is one node: a "{" which turns out to be no
    # placeholder would otherwise split the line into pieces.
    def add(node)
      last = @stack.last.last
      return @stack.last << node unless node.is_a?(Text) && last.is_a?(Text)

      last.text += node.text
    end

    # A closing bracket without an opening one is text, and so are the brackets
    # of a markdown link - what they hold stays as it is, placeholders included,
    # so the link text may come from a field.
    def close_group
      return add Text.new(GROUP_CLOSE) if @stack.size == 1

      children = @stack.pop
      return add Group.new(children) unless @scanner.match? LINK_RE

      add Text.new(GROUP_OPEN)
      children.each { |child| add child }
      add Text.new(GROUP_CLOSE)
    end

    # An opening bracket which is never closed is text as well, together with
    # everything it seemed to hold.
    def close_open_groups
      while @stack.size > 1
        children = @stack.pop
        add Text.new(GROUP_OPEN)
        children.each { |child| add child }
      end
    end
  end
end
