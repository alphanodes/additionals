# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class FieldTemplateParserTest < Additionals::TestCase
  def test_plain_text_stays_one_node
    nodes = parse 'just text'

    assert_equal 1, nodes.size
    assert_equal 'just text', nodes.first.text
  end

  def test_reads_a_placeholder_by_its_name
    nodes = parse '{%name%} of it'

    assert_equal 'name', nodes.first.name
    assert_equal ' of it', nodes.second.text
  end

  # the parser says where a placeholder is, not what it means
  def test_a_condition_is_a_placeholder_like_any_other
    assert_equal '?Location=Office', parse('{%?Location=Office%}').first.name
  end

  def test_reads_an_optional_part_as_a_group
    nodes = parse '{%name%}[ ({%cf_42%})]'
    group = nodes.second

    assert_kind_of Additionals::FieldTemplateParser::Group, group
    assert_equal ' (', group.children.first.text
    assert_equal 'cf_42', group.children.second.name
  end

  def test_reads_a_group_inside_a_group
    inner = parse('[a[b]]').first.children.second

    assert_kind_of Additionals::FieldTemplateParser::Group, inner
    assert_equal 'b', inner.children.first.text
  end

  # a template is written by hand and may carry a bracket which is not meant
  # as an optional part
  def test_a_closing_bracket_without_an_opening_one_is_text
    assert_equal 'a] b', parse('a] b').map(&:text).join
  end

  def test_an_opening_bracket_which_is_never_closed_is_text
    nodes = parse '{%name%} [sic'

    assert_equal 'name', nodes.first.name
    assert_equal ' [sic', nodes.second.text
  end

  # a part whose closing bracket was forgotten: its condition would quietly
  # stop working and the bracket would show up in every line. Refused where a
  # template is saved; rendering reads it as text, so a template saved before
  # keeps working.
  def test_refuses_a_part_never_closed_which_holds_a_placeholder_when_strict
    { '- {%link%}[ {%?tags=Done%}x' => '[ {%?tags=Done%}x',
      '[a {%name%}' => '[a {%name%}',
      '{%name%}[ ({%join(", ", A, B)%})' => '[ ({%join(", ", A, B)%})',
      '[[{%name%}] x' => '[[{%name%}] x' }.each do |template, excerpt|
      error = assert_raises(Additionals::FieldTemplate::Error, template) { parse template, strict: true }

      assert_equal :error_field_template_group_not_closed, error.key, template
      assert_equal({ name: excerpt }, error.params, template)
    end

    assert_equal(['[a ', 'name'], parse('[a {%name%}').map { |node| node.try(:text) || node.name })
  end

  # a macro in the template must pass through untouched
  def test_a_single_brace_is_text
    assert_equal '{{issue(', parse('{{issue({%id%})}}').first.text
  end

  def test_an_empty_template_has_no_nodes
    assert_empty parse('')
  end

  # field names are written by hand and are german more often than not
  def test_reads_a_name_with_non_ascii_characters
    assert_equal 'Größe in m²', parse('{%Größe in m²%}').first.name
  end

  # there used to be a fixed limit of ten levels, because the old renderer
  # resolved the parts in a loop
  def test_reads_parts_nested_deeper_than_ten_levels
    nodes = parse "#{'[' * 15}{%name%}#{']' * 15}"
    depth = 0
    node = nodes.first
    while node.is_a? Additionals::FieldTemplateParser::Group
      depth += 1
      node = node.children.first
    end

    assert_equal 15, depth
    assert_equal 'name', node.name
  end

  # the brackets of a markdown link are not an optional part - what they hold
  # stays, placeholders included
  def test_brackets_followed_by_a_round_one_are_a_link
    nodes = parse '[{%Name%}](/issues/{%id%})'

    assert_none_of_them_is_a_group nodes
    assert_equal '[', nodes.first.text
    assert_equal 'Name', nodes.second.name
    assert_equal '](/issues/', nodes.third.text
    assert_equal 'id', nodes.fourth.name
    assert_equal ')', nodes.last.text
  end

  def test_a_link_without_a_placeholder_stays_text
    nodes = parse '[Manual](/manual.pdf)'

    assert_none_of_them_is_a_group nodes
    assert_equal '[Manual](/manual.pdf)', nodes.map(&:text).join
  end

  # only the round bracket right behind the closing one makes a link
  def test_brackets_with_a_space_before_the_round_one_stay_an_optional_part
    assert_kind_of Additionals::FieldTemplateParser::Group, parse('[{%Name%}] ({%id%})').first
  end

  def test_reads_a_function_with_its_arguments
    node = parse('{%join(", ", Owner, cf_42)%}').first

    assert_kind_of Additionals::FieldTemplateParser::Function, node
    assert_equal 'join', node.name
    assert_equal 'join(", ", Owner, cf_42)', node.source
    assert_equal [', ', 'Owner', 'cf_42'], node.arguments.map(&:value)
    assert_equal [true, false, false], node.arguments.map(&:literal)
  end

  # the separator of a join carries a comma more often than not
  def test_a_quoted_argument_keeps_its_comma
    node = parse('{%join(", ", A)%}').first

    assert_equal 2, node.arguments.size
    assert_equal ', ', node.arguments.first.value
  end

  # which functions exist is decided by FieldTemplate, not here
  def test_an_unknown_function_is_read_like_any_other
    assert_equal 'nope', parse('{%nope(a)%}').first.name
  end

  def test_reports_a_placeholder_which_cannot_be_read
    error = assert_raises Additionals::FieldTemplate::Error do
      parse '{%name%} {%cf_1=100%%}'
    end

    assert_equal :error_field_template_placeholder_not_readable, error.key
    assert_equal '{%cf_1=100%%}', error.params[:name]
  end

  # what a placeholder or a part which is not closed reports, and from where
  def test_reports_where_a_placeholder_or_a_part_is_not_closed
    cases = { '{%name%} {%Location' => [:error_field_template_placeholder_not_readable, '{%Location'],
              "{%name%} {%#{'x' * 40}" => [:error_field_template_placeholder_not_readable, "{%#{'x' * 30}"],
              'a] [{%name%} b' => [:error_field_template_group_not_closed, '[{%name%} b'],
              '[ [{%name%}](/x) b' => [:error_field_template_group_not_closed, '[ [{%name%}](/x) b'] }
    cases.each do |template, (key, excerpt)|
      error = assert_raises(Additionals::FieldTemplate::Error, template) { parse template, strict: true }

      assert_equal key, error.key, template
      assert_equal({ name: excerpt }, error.params, template)
    end
  end

  # the brackets of a link are text, the part around it stays a part
  def test_reads_a_link_inside_an_optional_part
    group = parse('[ [{%Name%}](/issues/{%id%})]').first

    assert_kind_of Additionals::FieldTemplateParser::Group, group
    assert_equal([' [', 'Name', '](/issues/', 'id', ')'], group.children.map { |node| node.try(:text) || node.name })
  end

  def test_drops_empty_arguments_and_spaces_around_a_name
    function = parse('{% join(", ", , A) %}').first

    assert_equal [', ', 'A'], function.arguments.map(&:value)
    assert_equal 'name', parse('{% name %}').first.name
  end

  def test_placeholder_names_lists_them_in_order_without_a_tree
    assert_equal %w[name ?cf_1 cf_2],
                 Additionals::FieldTemplateParser.placeholder_names('{% name %}[ {%?cf_1%}({%cf_2%})]')
  end

  private

  def parse(template, strict: false)
    Additionals::FieldTemplateParser.parse template, strict:
  end

  def assert_none_of_them_is_a_group(nodes)
    assert_empty nodes.grep(Additionals::FieldTemplateParser::Group)
  end
end
