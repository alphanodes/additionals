# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

Redmine::WikiFormatting::Macros.register do
  desc 'Lists the first three issues, for the tests of nested lists'
  macro :additionals_test_issue_list do |obj, args, text|
    list = FieldListTest::IssueList.new args, text, fields: [], issues: Issue.where(id: [1, 2, 3]), project: Project.find(1)
    render_field_list list, obj, css_class: 'issue-list'
  end
end

class FieldListTest < Additionals::TestCase
  include Redmine::I18n

  # A list over core issues, the way a plugin builds its list macro. Which
  # records there are is up to the list, so it takes them as given.
  class IssueList < Additionals::FieldList
    # the subject of an issue, the rest are its custom fields
    class Source < Additionals::FieldTemplateSource
      def initialize(fields)
        super()
        @fields = fields
      end

      def placeholders
        { 'subject' => :field_subject }
      end

      def custom_fields
        @fields
      end

      def attribute_value(issue, name)
        name == 'subject' ? issue.subject.to_s : super
      end
    end

    def initialize(args, template, fields:, issues:, project: nil)
      @fields = fields
      @issue_ids = issues.map(&:id)

      super(args, template, project:)
    end

    private

    def default_template
      '- {%subject%}'
    end

    def block_language
      'issue_list'
    end

    def reserved_options
      %w[sort]
    end

    def records
      scope = Issue.visible.where id: @issue_ids
      @filters.each do |filter|
        scope = filter_by_custom_field scope, find_field(filter.name, 'filter'), filter
      end
      scope
    end

    def sort_attributes
      { 'subject' => :subject.to_proc }
    end

    def renderer
      @renderer ||= Additionals::FieldTemplate.new Source.new(@fields), escape_macros: true
    end

    def available_fields
      @fields
    end

    def default_sort_value(issue)
      issue.subject
    end
  end

  def setup
    prepare_tests
    User.current = users :users_001

    @position = build_field 'Position', 'int'
    @number = build_field 'Number', 'string'
    @location = build_field 'Location', 'list', possible_values: %w[Office Storage]
    @grade = build_field 'Grade', 'list', possible_values: %w[PD F EN]
    @parts = build_field 'Parts', 'list', possible_values: %w[Cable Battery], multiple: true
    @route = build_field 'Route', 'text'
    @fields = [@position, @number, @location, @grade, @parts, @route]

    @computer = named :issues_001, 'Computer'
    @mouse = named :issues_002, 'Mouse'
    @keyboard = named :issues_003, 'Keyboard'
  end

  def test_sorts_by_custom_field_and_puts_empty_values_last
    set_values @computer, @position => '10'
    set_values @mouse, @position => '2'
    set_values @keyboard, @position => ''

    assert_equal ['- Mouse', '- Computer', '- Keyboard'], lines('- {%subject%}', 'sort=Position')
  end

  def test_sorts_a_text_field_by_its_digit_and_text_parts
    set_values @computer, @number => '12'
    set_values @mouse, @number => '2'
    set_values @keyboard, @number => '12a'

    assert_equal ['- Mouse', '- Computer', '- Keyboard'], lines('- {%subject%}', 'sort=Number')
  end

  def test_sorts_by_the_default_value_without_sort_argument
    assert_equal ['- Computer', '- Keyboard', '- Mouse'], lines('- {%subject%}')
  end

  # a shortened list would look complete, so too many records are an error
  def test_raises_when_more_records_exist_than_the_maximum
    stub_const Additionals::FieldList, :MAX_ENTRIES, 1 do
      error = assert_raises Additionals::FieldList::Error do
        lines '- {%subject%}'
      end

      assert_equal :error_field_list_too_many_entries, error.key
      assert_equal 'More than 1 entries found. Narrow the list down.', error.message
    end
  end

  # reported whether or not there is a record to sort
  def test_raises_for_an_unknown_field
    error = assert_raises Additionals::FieldList::Error do
      build_list('- {%subject%}', 'sort=Nope', issues: []).to_wiki_text
    end

    assert_equal :error_field_list_unknown_field, error.key
    assert_equal({ argument: 'sort', name: 'Nope' }, error.params)
  end

  def test_raises_for_an_argument_without_value
    error = assert_raises Additionals::FieldList::Error do
      build_list '- {%subject%}', 'broken'
    end

    assert_equal :error_field_list_argument_without_value, error.key
    assert_equal 'broken', error.params[:argument]
  end

  # The formatter reads "38. " as a list marker and then counts on its own,
  # which loses every number but the first. The mark has to stay text.
  def test_renders_a_number_of_the_record_as_a_mark_of_its_own
    numbered '38', '12a'

    assert_equal ['- <span>12a. </span>Mouse', '- <span>38. </span>Computer'],
                 lines('{%Number%}. {%subject%}', 'sort=Number', issues: [@computer, @mouse])
  end

  def test_renders_a_mark_written_as_an_optional_part
    numbered '38', '12a'

    assert_equal ['- <span>12a. </span>Mouse', '- <span>38. </span>Computer'],
                 lines('[{%Number%}. ]{%subject%}', 'sort=Number', issues: [@computer, @mouse])
  end

  # the mark is optional there, and a line without one has to keep its own
  # place in the list instead of joining the line above it
  def test_keeps_the_place_of_a_record_whose_number_is_empty
    numbered '38', ''

    assert_equal ['- <span>38. </span>Computer', '- <span> </span>Mouse'],
                 lines('[{%Number%}. ]{%subject%}', issues: [@computer, @mouse])
  end

  def test_marks_a_line_of_a_closing_bracket_as_well
    numbered '38', '12a'

    assert_equal ['- <span>12a) </span>Mouse', '- <span>38) </span>Computer'],
                 lines('{%Number%}) {%subject%}', 'sort=Number', issues: [@computer, @mouse])
  end

  def test_reports_the_width_of_the_longest_mark
    numbered '38', '12a'
    list = build_list '{%Number%}. {%subject%}', issues: [@computer, @mouse]
    list.to_wiki_text

    assert list.marked?
    assert_equal 4, list.mark_width
  end

  # a number written down by hand asks for the list to be counted, and that is
  # what the formatter does with it - nothing to correct here
  def test_leaves_a_mark_of_fixed_text_alone
    numbered '38', '12a'
    list = build_list '1. {%subject%}', issues: [@computer, @mouse]

    assert_equal ['1. Computer', '1. Mouse'], list.to_wiki_text.split("\n")
    assert_not list.marked?
  end

  def test_leaves_a_template_without_a_mark_alone
    numbered '38', '12a'
    list = build_list '- {%subject%}', issues: [@computer, @mouse]

    assert_equal ['- Computer', '- Mouse'], list.to_wiki_text.split("\n")
    assert_not list.marked?
  end

  # an optional part which holds more than the number is not a mark, it is a
  # part of the line
  def test_does_not_read_a_larger_optional_part_as_a_mark
    numbered '38', '12a'
    list = build_list '[{%Number%}. {%subject%}]', issues: [@computer, @mouse]
    list.to_wiki_text

    assert_not list.marked?
  end

  # type=none is the one spelling every renderer understands, the pdf export
  # included; without it a bullet appears in front of every number there
  def test_mark_list_labels_the_list_for_every_renderer
    numbered '38', '12a'
    list = build_list '{%Number%}. {%subject%}', issues: [@computer, @mouse]
    list.to_wiki_text

    html = list.mark_list "<ul>\n<li><span>38. </span>Computer</li>\n</ul>"
    list_tag = Nokogiri::HTML5.fragment(html).children.first

    assert_equal 'none', list_tag['type']
    assert_equal 'additionals-list-marks', list_tag['class']
    assert_equal '--a-list-mark-width: 4ch', list_tag['style']
  end

  def test_a_filter_compares_without_regard_to_case
    located

    assert_equal ['- Computer'], lines('- {%subject%}', 'Location=office')
  end

  # a record without a value does not carry the one asked for either
  def test_a_negated_filter_keeps_records_without_a_value
    located

    assert_equal ['- Keyboard', '- Mouse'], lines('- {%subject%}', 'Location!=Office')
  end

  def test_values_separated_by_a_bar_are_alternatives
    located

    assert_equal ['- Computer', '- Mouse'], lines('- {%subject%}', 'Location=Office|Storage')
    assert_equal ['- Computer', '- Keyboard'], lines('- {%subject%}', 'Location=none|Office')
    assert_equal ['- Keyboard'], lines('- {%subject%}', 'Location!=Office|Storage')
  end

  def test_a_negated_keyword_is_its_counterpart
    located

    assert_equal ['- Computer', '- Mouse'], lines('- {%subject%}', 'Location!=none')
    assert_equal ['- Keyboard'], lines('- {%subject%}', 'Location!=any')
  end

  def test_a_multi_value_field_is_asked_whether_it_contains_the_value
    set_values @computer, @parts => %w[Cable Battery]
    set_values @mouse, @parts => %w[Battery]

    assert_equal ['- Computer'], lines('- {%subject%}', 'Parts=Cable')
    assert_equal ['- Keyboard', '- Mouse'], lines('- {%subject%}', 'Parts!=Cable')
  end

  def test_contains_looks_for_a_part_of_a_text
    set_values @computer, @route => 'Nordkante'
    set_values @mouse, @route => 'Südwand'

    assert_equal ['- Computer'], lines('- {%subject%}', 'Route~KANT')
    assert_equal ['- Keyboard', '- Mouse'], lines('- {%subject%}', 'Route!~kant')
  end

  # a list value or a number has no part to look for
  def test_contains_is_refused_for_a_field_which_is_not_text
    error = assert_raises Additionals::FieldList::Error do
      lines '- {%subject%}', 'Location~Off'
    end

    assert_equal :error_field_list_operator_not_supported, error.key
    assert_equal({ operator: '~', name: 'Location' }, error.params)
  end

  def test_an_option_takes_only_the_equals_sign
    error = assert_raises Additionals::FieldList::Error do
      build_list '- {%subject%}', 'sort!=Position'
    end

    assert_equal :error_field_list_operator_not_supported, error.key
    assert_equal({ operator: '!=', name: 'sort' }, error.params)
  end

  # the second one would otherwise quietly replace the first
  def test_an_argument_given_twice_is_an_error
    error = assert_raises Additionals::FieldList::Error do
      build_list '- {%subject%}', 'Location=Office', 'location!=Storage'
    end

    assert_equal :error_field_list_duplicate_argument, error.key
    assert_equal({ argument: 'location!=Storage' }, error.params)
  end

  def test_a_field_is_found_by_its_id_and_its_name_in_any_case
    located

    assert_equal ['- Computer'], lines('- {%subject%}', "cf_#{@location.id}=Office")
    assert_equal ['- Computer'], lines('- {%subject%}', 'LOCATION=Office')
  end

  def test_sorts_a_list_field_by_the_order_of_its_values
    set_values @computer, @grade => 'EN'
    set_values @mouse, @grade => 'PD'
    set_values @keyboard, @grade => 'F'

    assert_equal ['- Mouse', '- Keyboard', '- Computer'], lines('- {%subject%}', 'sort=Grade')
  end

  def test_sorts_a_key_value_field_by_the_position_of_its_values
    field = build_field 'Priority', 'enumeration'
    low = field.enumerations.create! name: 'Low', active: true
    high = field.enumerations.create! name: 'High', active: true
    # the order runs against the ids, so they cannot give it away
    low.update_column :position, 2
    high.update_column :position, 1
    # read fresh, the way a list finds it
    @fields << field.reload
    set_values @computer, field => low.id.to_s
    set_values @mouse, field => high.id.to_s

    assert_equal ['- Mouse', '- Computer', '- Keyboard'], lines('- {%subject%}', 'sort=Priority')
  end

  def test_sorts_descending_and_keeps_empty_values_last
    set_values @computer, @position => '10'
    set_values @mouse, @position => '2'

    assert_equal ['- Computer', '- Mouse', '- Keyboard'], lines('- {%subject%}', 'sort=-Position')
  end

  def test_sorts_by_an_attribute_the_list_offers
    assert_equal ['- Mouse', '- Keyboard', '- Computer'], lines('- {%subject%}', 'sort=-subject')
  end

  # a line of its own for every record, also where markdown would join them
  def test_a_line_without_a_list_marker_ends_with_a_hard_break_in_markdown
    with_settings text_formatting: 'common_mark' do
      assert_equal "Computer\\\nKeyboard\\\nMouse", build_list('{%subject%}').to_wiki_text
      assert_equal "- Computer\n- Keyboard\n- Mouse", build_list('- {%subject%}').to_wiki_text
    end
    with_settings text_formatting: 'textile' do
      assert_equal "Computer\nKeyboard\nMouse", build_list('{%subject%}').to_wiki_text
    end
  end

  # an empty value could never be meant, the list would just stay empty
  def test_an_empty_value_is_reported
    %w[Location= Location!= Location=Office| Location=|Office].each do |argument|
      error = assert_raises Additionals::FieldList::Error do
        build_list '- {%subject%}', argument
      end

      assert_equal :error_field_list_argument_without_value, error.key, argument
    end
  end

  # "_" and "%" are wildcards of the database, not of the macro
  def test_a_filter_value_is_taken_literally
    set_values @computer, @number => '12'
    set_values @mouse, @number => '1_'

    assert_equal ['- Mouse'], lines('- {%subject%}', 'Number=1_')
    assert_empty lines('- {%subject%}', 'Number=%')
  end

  # the same value keeps the default order, in both directions
  def test_records_with_the_same_sort_value_keep_the_default_order
    set_values @computer, @grade => 'F'
    set_values @keyboard, @grade => 'F'
    set_values @mouse, @grade => 'EN'

    assert_equal ['- Computer', '- Keyboard', '- Mouse'], lines('- {%subject%}', 'sort=Grade')
    assert_equal ['- Mouse', '- Computer', '- Keyboard'], lines('- {%subject%}', 'sort=-Grade')
  end

  # markdown keeps the backslash of a heading, an html line or an empty line
  def test_a_hard_break_is_left_out_where_markdown_would_print_it
    with_settings text_formatting: 'common_mark' do
      assert_equal "## Computer\n## Keyboard\n## Mouse", build_list('## {%subject%}').to_wiki_text
      assert_equal "<b>Computer</b>\n<b>Keyboard</b>\n<b>Mouse</b>", build_list('<b>{%subject%}</b>').to_wiki_text
      assert_equal "\n\n", build_list('[{%Number%}]').to_wiki_text
    end
  end

  def test_reads_the_template_from_the_block_of_a_wiki_page
    with_settings text_formatting: 'common_mark' do
      template_page

      assert_equal ['- Computer!', '- Keyboard!', '- Mouse!'],
                   lines(nil, 'template=CookBook documentation', project: projects(:projects_001))
      assert_equal ['- Computer!', '- Keyboard!', '- Mouse!'], lines(nil, 'template=ecookbook:CookBook_documentation')
    end
  end

  def test_block_of_the_macro_wins_over_the_template_page
    with_settings text_formatting: 'common_mark' do
      template_page
      list = build_list '- {%subject%}?', 'template=ecookbook:CookBook_documentation'

      assert_nil list.template_page
      assert_equal "- Computer?\n- Keyboard?\n- Mouse?", list.to_wiki_text
    end
  end

  def test_raises_for_an_option_without_value
    error = assert_raises Additionals::FieldList::Error do
      build_list nil, 'template='
    end

    assert_equal :error_field_list_argument_without_value, error.key
  end

  def test_falls_back_to_the_default_template
    assert_equal ['- Computer', '- Keyboard', '- Mouse'], lines(nil)
  end

  # Neither a missing page nor a hidden one may give away whether it exists
  def test_a_missing_or_hidden_template_page_is_not_available
    assert_raises Additionals::FieldList::NotAvailable do
      build_list(nil, 'template=ecookbook:Nope').template_page
    end

    User.current = User.anonymous

    assert_raises Additionals::FieldList::NotAvailable do
      build_list(nil, 'template=onlinestore:Start_page').template_page
    end
  end

  def test_raises_for_a_template_page_without_block
    with_settings text_formatting: 'common_mark' do
      template_page 'No template here.'
      error = assert_raises Additionals::FieldList::Error do
        build_list(nil, 'template=ecookbook:CookBook_documentation').to_wiki_text
      end

      assert_equal :error_field_template_block_missing, error.key
      assert_equal({ page: 'CookBook documentation', language: 'issue_list' }, error.params)
    end
  end

  def test_render_field_list_renders_the_lines_as_html
    html = build_redmine_view.render_field_list build_list('- {%subject%}'), nil, css_class: 'issue-list'

    assert_equal 3, Nokogiri::HTML5.fragment(html).css('div.issue-list li').size
  end

  def test_render_field_list_shows_a_notice_for_a_template_page_which_is_not_available
    html = build_redmine_view.render_field_list build_list(nil, 'template=ecookbook:Nope'), nil, css_class: 'issue-list'

    assert_equal 1, Nokogiri::HTML5.fragment(html).css('span.macro-not-available').size
  end

  def test_raises_for_an_option_given_twice
    error = assert_raises Additionals::FieldList::Error do
      build_list '- {%subject%}', 'sort=subject', 'sort=Position'
    end

    assert_equal :error_field_list_duplicate_argument, error.key
  end

  # read like text: naturally and without regard to case
  def test_sorts_by_default_naturally_and_without_regard_to_case
    @computer.update_columns subject: 'Part 10'
    @mouse.update_columns subject: 'part 2'
    @keyboard.update_columns subject: 'Part 1'

    assert_equal ['- Part 1', '- part 2', '- Part 10'], lines('- {%subject%}')
  end

  # the ids a reference field stores say nothing about the order
  def test_sorts_a_reference_field_by_the_name_it_shows
    owner = build_field 'Owner', 'user'
    @fields << owner
    set_values @computer, owner => users(:users_003).id.to_s
    set_values @mouse, owner => users(:users_002).id.to_s

    assert_equal ['- Computer', '- Mouse', '- Keyboard'], lines('- {%subject%}', 'sort=Owner')
  end

  def test_renders_the_marks_of_a_numbered_list_in_textile
    numbered '38', '12a'

    with_settings text_formatting: 'textile' do
      html = build_redmine_view.render_field_list build_list('[{%Number%}. ]{%subject%}', 'sort=Number'), nil, css_class: 'issue-list'
      items = Nokogiri::HTML5.fragment(html).css('ul.additionals-list-marks > li')

      assert_equal([['12a.', '12a. Mouse'], ['38.', '38. Computer'], ["\u00a0", 'Keyboard']], items.map do |item|
        [item.at_css('span').text, item.text.squish]
      end)
    end
  end

  # A line may hold a list again, but neither endlessly nor the template page
  # which is rendered already
  def test_render_field_list_limits_nested_lists
    with_settings text_formatting: 'common_mark' do
      template_page "```issue_list\n- {%subject%} {{additionals_test_issue_list(template=ecookbook:CookBook_documentation)}}\n```"

      html = render_test_macro 'template=ecookbook:CookBook_documentation'

      assert_includes html, ERB::Util.html_escape(l(:error_circular_inclusion))

      # every level takes its line from the next template page
      %w[Level_2 Level_3 Level_4].each_cons 2 do |page, next_page|
        add_template_page page, "- {%subject%} {{additionals_test_issue_list(template=ecookbook:#{next_page})}}"
      end
      add_template_page 'Level_4', '- {%subject%}'
      html = render_test_macro "\n- {%subject%} {{additionals_test_issue_list(template=ecookbook:Level_2)}}\n"

      assert_includes html, ERB::Util.html_escape(l(:error_field_list_nested_too_deep, depth: 3))
    end
  end

  def test_render_field_list_limits_the_lines_of_nested_lists_together
    stub_const Additionals::FieldList, :MAX_ENTRIES, 4 do
      html = render_test_macro "\n- {%subject%} {{additionals_test_issue_list}}\n"

      assert_includes html, ERB::Util.html_escape(l(:error_field_list_too_many_entries, count: 4))
    end
  end

  private

  def lines(template, *, issues: [@computer, @mouse, @keyboard], project: nil)
    build_list(template, *, issues:, project:).to_wiki_text.split "\n"
  end

  def build_list(template, *args, issues: [@computer, @mouse, @keyboard], project: nil)
    IssueList.new args, template, fields: @fields, issues:, project:
  end

  # The documentation page of the first project, holding a template block
  def template_page(text = "Explained here.\n\n```issue_list\n- {%subject%}!\n```\n")
    page = wiki_pages :wiki_pages_001
    page.content.update_column :text, text
    page
  end

  def numbered(computer, mouse)
    set_values @computer, @number => computer
    set_values @mouse, @number => mouse
  end

  def named(fixture, subject)
    issue = issues fixture
    issue.update_columns subject: subject
    issue
  end

  def build_field(name, format, **attributes)
    IssueCustomField.create!(name:, field_format: format, is_for_all: true, trackers: Tracker.all, **attributes)
  end

  def located
    set_values @computer, @location => 'Office'
    set_values @mouse, @location => 'Storage'
  end

  # stored, because the list reads its records from the database
  def set_values(issue, values)
    values.each do |field, value|
      Array(value).each { |single| CustomValue.create! customized: issue, custom_field: field, value: single }
    end
  end

  def add_template_page(title, line)
    page = WikiPage.new wiki: projects(:projects_001).wiki, title: title
    page.content = WikiContent.new text: "```issue_list\n#{line}\n```", author: users(:users_001)
    page.save!
  end

  # The macro renders the list of the test, so lists can be nested the way a
  # template nests them in a wiki page
  def render_test_macro(args_or_block)
    text = if args_or_block.start_with? "\n"
             "{{additionals_test_issue_list#{args_or_block}}}"
           else
             "{{additionals_test_issue_list(#{args_or_block})}}"
           end
    build_redmine_view.textilizable text
  end
end
