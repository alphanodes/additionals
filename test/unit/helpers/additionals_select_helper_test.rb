# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class AdditionalsSelectHelperTest < Additionals::HelperTest
  def setup
    super
    # not @view, ActionView::TestCase keeps its own view there
    @redmine_view = build_redmine_view
  end

  def test_labels_of_select_fields_come_in_the_language_of_the_page
    labels = I18n.with_locale(:de) { @redmine_view.additionals_select_labels }

    assert_equal({ search: I18n.t(:label_search, locale: :de), noResults: I18n.t(:label_no_data, locale: :de),
                   clear: I18n.t(:button_clear, locale: :de), remove: I18n.t(:button_remove, locale: :de) },
                 labels)
  end

  def test_select_field_gets_controller_and_values_of_the_field
    select = select_of @redmine_view.additionals_select_tag('foo', nil, url: '/search?a=1&b=2', tags: true,
                                                                        free_input: true, free_input_pattern: '@',
                                                                        renderer: 'avatar', min_input_length: 2)

    assert_equal({ 'data-controller' => 'additionals-select',
                   'data-additionals-select-url-value' => '/search?a=1&b=2',
                   'data-additionals-select-tags-value' => 'true',
                   'data-additionals-select-free-input-value' => 'true',
                   'data-additionals-select-free-input-pattern-value' => '@',
                   'data-additionals-select-renderer-value' => 'avatar',
                   'data-additionals-select-min-input-length-value' => '2' },
                 data_attributes(select))
  end

  # The pattern is checked in the browser, a Regexp passes its source
  def test_select_field_takes_a_regexp_as_pattern
    select = select_of @redmine_view.additionals_select_tag('foo', nil, free_input: true, free_input_pattern: /^[^@]+@/)
    script = @redmine_view.additionals_select_filter type: 'author', free_input: true, free_input_pattern: /@/

    assert_equal '^[^@]+@', select['data-additionals-select-free-input-pattern-value']
    assert_includes script, '"freeInputPattern":"@"'
  end

  # values left out fall back to the defaults of the controller
  def test_select_field_leaves_out_unset_values
    select = select_of @redmine_view.additionals_select_tag('foo', nil, tags: false, placeholder: '', url: nil)

    assert_equal({ 'data-controller' => 'additionals-select' }, data_attributes(select))
  end

  def test_select_field_keeps_other_controllers_and_html_options
    select = select_of @redmine_view.additionals_select_tag('foo', nil, id: 'my_id', class: 'wide', disabled: true,
                                                                        data: { controller: 'other', role: 'x' })

    assert_equal ['my_id', 'wide', 'disabled', 'other additionals-select', 'x'],
                 [select['id'], select['class'], select['disabled'], select['data-controller'], select['data-role']]
  end

  def test_single_select_keeps_its_blank_option
    html = @redmine_view.additionals_select_tag 'foo', nil, include_blank: true

    assert_not_nil Nokogiri::HTML.fragment(html).at('option[value=""]')
    assert_nil Nokogiri::HTML.fragment(html).at('input[type=hidden]')
  end

  # Clearing goes back to the blank option; without one nothing is selected,
  # the form leaves the field out and the old value stays
  def test_single_select_with_allow_clear_gets_one_blank_option
    chosen = @redmine_view.options_for_select [%w[One 1]], '1'
    with_blank = @redmine_view.options_for_select [['', ''], %w[One 1]], '1'

    # option tags written by hand may quote the blank value with '
    hand_written = ActiveSupport::SafeBuffer.new("<option value=''></option>") + chosen

    blank_options = [chosen, with_blank, hand_written].map do |option_tags|
      html = @redmine_view.additionals_select_tag 'foo', option_tags, allow_clear: true
      Nokogiri::HTML.fragment(html).css('option[value=""]').size
    end

    assert_equal [1, 1, 1], blank_options
  end

  # an include_blank of the caller stays as it is
  def test_allow_clear_keeps_include_blank_of_the_caller
    option_tags = @redmine_view.options_for_select [%w[One 1]], '1'
    blanks = ['none', false].map do |include_blank|
      html = @redmine_view.additionals_select_tag 'foo', option_tags, allow_clear: true, include_blank: include_blank
      Nokogiri::HTML.fragment(html).at('option[value=""]')&.text
    end

    assert_equal ['none', nil], blanks
  end

  # The hidden field clears a multiple select, a blank option would show up as
  # an empty choice after "clear all"
  def test_multiple_select_clears_through_a_hidden_field
    html = Nokogiri::HTML.fragment @redmine_view.additionals_select_tag('foo', nil, multiple: true, include_blank: true)

    assert_nil html.at('option[value=""]')
    assert_equal %w[foo[] foo[]], [html.at('select')['name'], html.at('input[type=hidden]')['name']]
  end

  # A name ending in [] (multiple custom fields) would otherwise become [][],
  # which Rack parses into a nested value
  def test_hidden_field_does_not_double_the_brackets_of_an_array_name
    html = Nokogiri::HTML.fragment @redmine_view.additionals_select_tag('foo[]', nil, multiple: true)

    assert_equal 'foo[]', html.at('input[type=hidden]')['name']
  end

  def test_multiple_select_without_hidden_field
    html = Nokogiri::HTML.fragment @redmine_view.additionals_select_tag('foo', nil, multiple: true, include_hidden: false)

    assert_nil html.at('input[type=hidden]')
  end

  def test_select_field_loads_the_library_once
    first = @redmine_view.additionals_select_tag 'foo', nil
    second = @redmine_view.additionals_select_tag 'bar', nil

    assert_predicate Nokogiri::HTML.fragment(first).css('script[src]'), :any?
    assert_empty Nokogiri::HTML.fragment(second).css('script[src]')
  end

  def test_filter_registers_options_by_the_kind_of_its_name
    html = @redmine_view.additionals_select_filter field_format: 'db_entry', url: '/entries?a=1&b=2',
                                                   min_input_length: 1, renderer: nil
    script = Nokogiri::HTML.fragment(html).css('script:not([src])').text

    assert_includes script,
                    'additionalsSelectRegisterFilter("fieldFormat", "db_entry", {"url":"/entries?a=1\\u0026b=2","minInputLength":1});'
  end

  def test_filter_needs_exactly_one_name
    assert_raises(ArgumentError) { @redmine_view.additionals_select_filter url: '/x' }
    assert_raises(ArgumentError) { @redmine_view.additionals_select_filter type: 'author', field: 'author_id' }
  end

  private

  def select_of(html)
    Nokogiri::HTML.fragment(html).at 'select'
  end

  def data_attributes(element)
    element.attributes.filter_map { |name, attr| [name, attr.value] if name.start_with? 'data-' }.to_h
  end
end
