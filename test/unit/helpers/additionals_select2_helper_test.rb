# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class AdditionalsSelect2HelperTest < Additionals::HelperTest
  include AdditionalsSelect2Helper

  def test_single_select_keeps_blank_option
    html = additionals_select2_tag 'foo',
                                   options_for_select([%w[Bar 1]]),
                                   multiple: false, include_blank: true

    assert_match(/<option value=""/, html)
  end

  def test_multiple_select_omits_blank_option
    html = additionals_select2_tag 'foo',
                                   options_for_select([%w[Bar 1]]),
                                   multiple: true, include_blank: true

    assert_no_match(/<option value=""/, html)
  end

  def test_multiple_select_adds_hidden_clear_field
    html = additionals_select2_tag 'foo',
                                   options_for_select([%w[Bar 1]]),
                                   multiple: true, include_blank: true

    assert_match(/<input[^>]*type="hidden"[^>]*name="foo\[\]"/, html)
  end

  def test_multiple_tags_select_has_no_blank_option
    html = additionals_select2_tag 'foo',
                                   options_for_select([%w[Bar 1]]),
                                   multiple: true, tags: true

    assert_no_match(/<option value=""/, html)
  end

  def test_multiple_select_hidden_field_appends_array_brackets_to_plain_name
    html = additionals_select2_tag 'foo',
                                   options_for_select([%w[Bar 1]]),
                                   multiple: true, include_blank: true

    assert_match(/<input[^>]*type="hidden"[^>]*name="foo\[\]"/, html)
  end

  def test_multiple_select_hidden_field_does_not_double_bracket_array_name
    html = additionals_select2_tag 'foo[]',
                                   options_for_select([%w[Bar 1]]),
                                   multiple: true, include_blank: true

    assert_match(/<input[^>]*type="hidden"[^>]*name="foo\[\]"/, html)
    assert_no_match(/name="foo\[\]\[\]"/, html)
  end
end
