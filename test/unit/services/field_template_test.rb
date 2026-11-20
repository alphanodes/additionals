# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__
require 'active_record/testing/query_assertions'

class FieldTemplateTest < Additionals::TestCase
  include ActiveRecord::Assertions::QueryAssertions

  include Redmine::I18n

  # A source over core issues, the way a plugin describes its records. The
  # short scope refuses the status, so a template of that scope shows what a
  # name which is reserved but not allowed does.
  class IssueSource < Additionals::FieldTemplateSource
    PLACEHOLDERS = { 'subject' => :field_subject,
                     'id' => 'ID',
                     'project' => :field_project,
                     'author' => :field_author,
                     'status' => :field_status }.freeze

    def initialize(fields, scope: :full, disabled: [], hidden: [])
      super()
      @fields = fields
      @scope = scope
      @disabled = disabled
      @hidden = hidden
    end

    def placeholders
      @scope == :short ? PLACEHOLDERS.except('status') : PLACEHOLDERS
    end

    def reserved_placeholders
      PLACEHOLDERS
    end

    def custom_fields
      @fields
    end

    def attribute_value(issue, name)
      case name
      when 'subject' then issue.subject.to_s
      when 'id' then issue.id.to_s
      when 'project' then issue.project&.name.to_s
      when 'author' then issue.author&.name.to_s
      when 'status' then issue.status&.name.to_s
      else super
      end
    end

    # the label changes with the language, a condition names a key instead
    def condition_value(issue, name)
      return issue.closed? ? 'closed' : 'open' if name == 'status'

      super
    end

    def placeholder_enabled?(name)
      @disabled.exclude? name
    end

    def field_readable?(field)
      @hidden.exclude? field
    end
  end

  def setup
    prepare_tests
    User.current = users :users_001

    @position = build_field 'Position', 'int'
    @location = build_field 'Location', 'list', possible_values: %w[Office Storage]
    @owner = build_field 'Owner', 'string'
    @year = build_field 'Year', 'int'
    @rating = build_field 'Rating', 'int'
    @active = build_field 'Active', 'bool'
    @assignee = build_field 'Assignee', 'user'
    @checked = build_field 'Checked', 'date'
    @platforms = build_field 'Platforms', 'list', possible_values: %w[A B C], multiple: true
    @fields = [@position, @location, @owner, @year, @rating, @active, @assignee, @checked, @platforms]

    @computer = issues :issues_001
    @computer.subject = 'Computer'
    @mouse = issues :issues_002
    @mouse.subject = 'Mouse'
  end

  def test_fills_the_placeholders
    set_values @computer, @position => '1', @owner => 'Jane'

    assert_equal '1. Computer (Jane)', render("{%cf_#{@position.id}%}. {%subject%} ({%cf_#{@owner.id}%})")
  end

  def test_placeholders_of_the_source_are_case_insensitive
    assert_equal "Computer #{@computer.id}", render('{%Subject%} {%ID%}')
    assert_equal @computer.project.name, render('{%Project%}')
  end

  def test_drops_a_group_when_all_its_placeholders_are_empty
    set_values @computer, @owner => '', @year => ''

    assert_equal 'Computer', render("{%subject%}[ ({%cf_#{@owner.id}%}[, {%cf_#{@year.id}%}])]")
  end

  def test_keeps_a_group_when_one_placeholder_has_a_value
    set_values @computer, @owner => 'Jane', @year => ''

    assert_equal 'Computer (Jane)', render("{%subject%}[ ({%cf_#{@owner.id}%}[, {%cf_#{@year.id}%}])]")
  end

  # a new record has none of its attributes yet, which is what the preview of
  # a form renders
  def test_drops_a_group_of_an_empty_attribute
    assert_equal 'Laptop', render('{%subject%}[ ({%author%})]', Issue.new(subject: 'Laptop'))
  end

  # A known limit: the part around it has no placeholder of its own left once
  # the inner one fell away, and brackets without a placeholder stay as they
  # were typed. Nobody writes this by hand - a part is wrapped around text,
  # not around another part alone.
  def test_a_part_left_without_a_placeholder_stays_as_brackets
    set_values @computer, @owner => ''

    assert_equal 'Computer[]', render("{%subject%}[[{%cf_#{@owner.id}%}]]")
  end

  def test_keeps_brackets_without_a_placeholder
    assert_equal 'Computer [fixed]', render('{%subject%} [fixed]')
  end

  def test_renders_a_markdown_link_with_a_placeholder_as_its_text
    set_values @computer, @owner => 'Jane'

    assert_equal "[Jane](/issues/#{@computer.id})", render("[{%cf_#{@owner.id}%}](/issues/{%id%})")
  end

  # A placeholder in the target of a link counts like any other, and an id is
  # always filled - so the part stays. A link which should come and go needs a
  # condition of its own.
  def test_a_placeholder_in_the_target_keeps_its_part_alive
    set_values @computer, @owner => ''

    assert_equal "Computer [](/issues/#{@computer.id})",
                 render("{%subject%}[ [{%cf_#{@owner.id}%}](/issues/{%id%})]")
  end

  def test_a_condition_makes_a_link_optional
    template = "{%subject%}[ {%?cf_#{@owner.id}%}[{%cf_#{@owner.id}%}](/issues/{%id%})]"

    set_values @computer, @owner => ''

    assert_equal 'Computer', render(template)

    set_values @computer, @owner => 'Jane'

    assert_equal "Computer [Jane](/issues/#{@computer.id})", render(template)
  end

  # a link whose address comes from a field has to disappear when the field is
  # empty, text and all
  def test_a_part_falls_away_when_the_target_of_its_link_is_empty
    template = "{%subject%}[ More: [Source]({%cf_#{@owner.id}%})]"

    set_values @computer, @owner => ''

    assert_equal 'Computer', render(template)

    set_values @computer, @owner => 'https://example.org'

    assert_equal 'Computer More: [Source](https://example.org)', render(template)
  end

  # only the round bracket right behind the closing one makes a link, so an
  # optional part in front of a text in brackets still works
  def test_a_part_before_a_round_bracket_with_a_space_is_still_optional
    set_values @computer, @owner => ''

    assert_equal 'Computer (fixed)', render("{%subject%}[ {%cf_#{@owner.id}%}] (fixed)")
  end

  def test_keeps_a_markdown_link
    set_values @computer, @owner => 'Jane'

    assert_equal 'Computer Jane [Manual](/manual.pdf)', render("{%subject%}[ {%cf_#{@owner.id}%}] [Manual](/manual.pdf)")
  end

  def test_condition_placeholder_decides_about_the_group_without_printing
    set_values @computer, @active => '1'
    set_values @mouse, @active => '0'

    assert_equal 'Computer in use', render("{%subject%}[ {%?cf_#{@active.id}%}in use]")
    assert_equal 'Mouse', render("{%subject%}[ {%?cf_#{@active.id}%}in use]", @mouse)
  end

  def test_zero_in_a_number_field_counts_as_a_value
    set_values @computer, @rating => '0'

    assert_equal 'Computer rated 0', render("{%subject%}[ rated {%cf_#{@rating.id}%}]")
  end

  def test_resolves_a_user_field_to_its_name
    user = users :users_002
    set_values @computer, @assignee => user.id.to_s

    assert_equal "Computer (#{user.name})", render("{%subject%} ({%cf_#{@assignee.id}%})")
  end

  def test_resolves_a_multi_value_field_to_all_values
    set_values @computer, @platforms => %w[A C]

    assert_equal 'Computer (A, C)', render("{%subject%} ({%cf_#{@platforms.id}%})")
  end

  # an empty multi value field holds [nil], which is not blank by itself
  def test_drops_the_group_of_an_empty_multi_value_field
    assert_equal 'Computer', render("{%subject%}[ ({%cf_#{@platforms.id}%})]")
  end

  def test_escapes_a_macro_in_a_value_only_when_asked_to
    @computer.subject = '{{toc}}'

    assert_equal '{{toc}}', render('{%subject%}')
    assert_equal '!{{toc}}', Additionals::FieldTemplate.new(source, escape_macros: true).render('{%subject%}', @computer)
  end

  def test_resolves_an_empty_reference_to_nothing
    set_values @computer, @assignee => ''

    assert_equal 'Computer', render("{%subject%}[ ({%cf_#{@assignee.id}%})]")
  end

  def test_formats_a_date_value_for_the_reader
    set_values @computer, @checked => '2026-08-13'

    assert_equal "Computer #{format_date Date.new(2026, 8, 13)}", render("{%subject%} {%cf_#{@checked.id}%}")
  end

  def test_formats_a_boolean_value_for_the_reader
    set_values @computer, @active => '1'
    set_values @mouse, @active => '0'

    assert_equal "Computer #{l :general_text_Yes}", render("{%subject%} {%cf_#{@active.id}%}")
    assert_equal "Mouse #{l :general_text_No}", render("{%subject%} {%cf_#{@active.id}%}", @mouse)
  end

  # the group is decided on the stored value, so a formatted "No" must not
  # keep the group alive
  def test_unchecked_boolean_still_counts_as_empty_for_a_group
    set_values @mouse, @active => '0'

    assert_equal 'Mouse', render("{%subject%}[ {%cf_#{@active.id}%}]", @mouse)
  end

  def test_keeps_a_list_value_as_it_is
    set_values @computer, @location => 'Office'

    assert_equal 'Computer Office', render("{%subject%} {%cf_#{@location.id}%}")
  end

  def test_raises_for_an_unknown_placeholder
    error = assert_raises Additionals::FieldTemplate::Error do
      render '{%Nope%}'
    end

    assert_equal :error_field_template_unknown_placeholder, error.key
    assert_equal 'Nope', error.params[:name]
  end

  # a template written by hand names its fields, the arguments of a list
  # macro do the same
  def test_a_field_can_be_addressed_by_its_name
    set_values @computer, @location => 'Office'

    assert_equal 'Computer Office', render('{%subject%} {%Location%}')
  end

  def test_a_field_name_is_matched_case_insensitively
    set_values @computer, @location => 'Office'

    assert_equal 'Office', render('{%location%}')
  end

  def test_a_field_name_decides_about_its_group
    set_values @computer, @location => 'Office'
    set_values @mouse, @location => ''

    assert_equal 'Computer in Office', render('{%subject%}[ in {%Location%}]')
    assert_equal 'Mouse', render('{%subject%}[ in {%Location%}]', @mouse)
  end

  # a name which neither the source nor a field knows is reported, also when
  # it looks like a field name
  def test_an_unknown_field_name_is_still_reported
    error = assert_raises Additionals::FieldTemplate::Error do
      render '{%Nowhere%}'
    end

    assert_equal :error_field_template_unknown_placeholder, error.key
    assert_equal 'Nowhere', error.params[:name]
  end

  # a condition may ask for a value, so one list field replaces a yes-no field
  # per case
  def test_a_condition_with_a_value_decides_on_that_value
    set_values @computer, @location => 'Office'
    set_values @mouse, @location => 'Storage'

    assert_equal 'Computer here', render("{%subject%}[ {%?cf_#{@location.id}=Office%}here]")
    assert_equal 'Mouse', render("{%subject%}[ {%?cf_#{@location.id}=Office%}here]", @mouse)
  end

  # the counterpart of {%?Field%}: a part which appears when another one fell
  # away
  def test_a_condition_on_none_is_met_by_an_empty_field
    set_values @computer, @location => ''
    set_values @mouse, @location => 'Office'

    assert_equal 'Computer missing', render('{%subject%}[ {%?Location=none%}missing]')
    assert_equal 'Mouse', render('{%subject%}[ {%?Location=none%}missing]', @mouse)
  end

  # the arguments of a list know "any", so a condition has to know it too -
  # otherwise it would look for a field carrying that value
  def test_a_condition_on_any_is_met_by_a_filled_field
    set_values @computer, @location => 'Office'
    set_values @mouse, @location => ''

    assert_equal 'Computer here', render('{%subject%}[ {%?Location=any%}here]')
    assert_equal 'Mouse', render('{%subject%}[ {%?Location=any%}here]', @mouse)
  end

  def test_a_condition_on_any_and_none_is_read_without_regard_to_case
    set_values @computer, @location => 'Office'
    set_values @mouse, @location => ''

    assert_equal 'Computer here', render('{%subject%}[ {%?Location=Any%}here]')
    assert_equal 'Mouse missing', render('{%subject%}[ {%?Location=None%}missing]', @mouse)
  end

  # an unchecked yes-no field holds a value, it is not empty
  def test_an_unchecked_yes_no_field_is_filled_for_any_and_none
    set_values @mouse, @active => '0'

    assert_equal 'Mouse set', render("{%subject%}[ {%?cf_#{@active.id}=any%}set]", @mouse)
    assert_equal 'Mouse', render("{%subject%}[ {%?cf_#{@active.id}=none%}missing]", @mouse)
  end

  def test_a_condition_on_none_is_met_by_an_empty_multi_value_field
    set_values @computer, @platforms => ['']

    assert_equal 'Computer missing', render("{%subject%}[ {%?cf_#{@platforms.id}=none%}missing]")
  end

  # The case it was built for: two parts which exclude each other, so a
  # separator never stands without the value it belongs to. The first part
  # needs its own condition as well - a filled year alone would keep it.
  def test_two_parts_which_exclude_each_other_through_none
    template = "{%subject%}[ {%?cf_#{@owner.id}%}({%cf_#{@owner.id}%}[, {%cf_#{@year.id}%}])]" \
               "[ {%?cf_#{@owner.id}=none%}({%cf_#{@year.id}%})]"

    set_values @computer, @owner => 'Jane', @year => '1979'

    assert_equal 'Computer (Jane, 1979)', render(template)

    set_values @computer, @owner => 'Jane', @year => ''

    assert_equal 'Computer (Jane)', render(template)

    set_values @computer, @owner => '', @year => '1979'

    assert_equal 'Computer (1979)', render(template)

    set_values @computer, @owner => '', @year => ''

    assert_equal 'Computer', render(template)
  end

  # only the leading "?" marks the condition, the one behind the "=" is the
  # value
  def test_a_condition_can_ask_for_a_question_mark_as_its_value
    @computer.subject = '?'

    assert_equal '? unnamed', render('{%subject%}[ {%?subject=?%}unnamed]')
    assert_equal 'Mouse', render('{%subject%}[ {%?subject=?%}unnamed]', @mouse)
  end

  def test_a_condition_with_a_value_is_read_without_regard_to_case
    set_values @computer, @location => 'Office'

    assert_equal 'Computer here', render("{%subject%}[ {%?cf_#{@location.id}=office%}here]")
  end

  def test_a_condition_with_a_value_addresses_a_field_by_its_name_as_well
    set_values @computer, @location => 'Office'

    assert_equal 'Computer here', render('{%subject%}[ {%?Location=Office%}here]')
  end

  def test_a_condition_asks_a_multi_value_field_whether_it_contains_the_value
    set_values @computer, @platforms => %w[A B]

    assert_equal 'Computer yes', render("{%subject%}[ {%?cf_#{@platforms.id}=B%}yes]")
    assert_equal 'Computer', render("{%subject%}[ {%?cf_#{@platforms.id}=C%}yes]")
  end

  def test_a_condition_on_an_empty_field_is_never_true
    set_values @computer, @location => ''

    assert_equal 'Computer', render("{%subject%}[ {%?cf_#{@location.id}=Office%}here]")
  end

  def test_a_condition_asks_a_yes_no_field_for_its_stored_value
    set_values @computer, @active => '1'
    set_values @mouse, @active => '0'

    assert_equal 'Computer in use', render("{%subject%}[ {%?cf_#{@active.id}=1%}in use]")
    assert_equal 'Mouse retired', render("{%subject%}[ {%?cf_#{@active.id}=0%}retired]", @mouse)
  end

  def test_a_condition_asks_a_reference_field_for_the_stored_id
    user = users :users_002
    set_values @computer, @assignee => user.id.to_s

    assert_equal 'Computer assigned', render("{%subject%}[ {%?cf_#{@assignee.id}=#{user.id}%}assigned]")
    assert_equal 'Computer', render("{%subject%}[ {%?cf_#{@assignee.id}=#{user.name}%}assigned]")
  end

  def test_a_condition_asks_a_date_field_for_the_stored_format
    set_values @computer, @checked => '2026-08-13'

    assert_equal 'Computer done', render("{%subject%}[ {%?cf_#{@checked.id}=2026-08-13%}done]")
  end

  def test_a_condition_keeps_an_equals_sign_inside_its_value
    set_values @computer, @owner => 'a=b'

    assert_equal 'Computer yes', render("{%subject%}[ {%?cf_#{@owner.id}=a=b%}yes]")
  end

  # a field of that name is still addressed by its name, the "=" only splits
  # a condition
  def test_a_placeholder_without_a_condition_is_not_split_at_an_equals_sign
    error = assert_raises Additionals::FieldTemplate::Error do
      render '{%Location=Office%}'
    end

    assert_equal :error_field_template_unknown_placeholder, error.key
    assert_equal 'Location=Office', error.params[:name]
  end

  # a record without a value does not carry the one asked for either
  def test_a_negated_condition_is_met_where_the_value_is_missing
    set_values @computer, @location => 'Office'

    assert_equal 'Computer', render('{%subject%}[ {%?Location!=Office%}elsewhere]')
    assert_equal 'Mouse elsewhere', render('{%subject%}[ {%?Location!=Office%}elsewhere]', @mouse)
  end

  def test_values_of_a_condition_separated_by_a_bar_are_alternatives
    set_values @computer, @location => 'Office'

    assert_equal 'Computer here', render('{%subject%}[ {%?Location=Storage|office%}here]')
    assert_equal 'Mouse here', render('{%subject%}[ {%?Location=none|Office%}here]', @mouse)
    assert_equal 'Computer', render('{%subject%}[ {%?Location!=Storage|Office%}here]')
  end

  def test_a_condition_asks_whether_a_text_contains_a_value
    set_values @computer, @owner => 'Jane Doe'

    assert_equal 'Computer doe', render('{%subject%}[ {%?Owner~DOE%}doe]')
    assert_equal 'Computer', render('{%subject%}[ {%?Owner!~doe%}other]')
    assert_equal 'Mouse other', render('{%subject%}[ {%?Owner!~doe%}other]', @mouse)
  end

  def test_a_negated_condition_asks_a_multi_value_field_for_all_its_values
    set_values @computer, @platforms => %w[A B]

    assert_equal 'Computer', render('{%subject%}[ {%?Platforms!=A%}without]')
    assert_equal 'Computer without', render('{%subject%}[ {%?Platforms!=C%}without]')
  end

  def test_a_condition_with_an_empty_alternative_is_reported
    error = assert_raises Additionals::FieldTemplate::Error do
      render '{%subject%}[ {%?Location=Office|%}here]'
    end

    assert_equal :error_field_template_condition_without_value, error.key
  end

  def test_a_condition_without_a_value_is_reported
    error = assert_raises Additionals::FieldTemplate::Error do
      render "{%subject%}[ {%?cf_#{@location.id}=%}here]"
    end

    assert_equal :error_field_template_condition_without_value, error.key
    assert_equal "?cf_#{@location.id}=", error.params[:name]
  end

  def test_a_condition_decides_a_nested_group
    set_values @computer, @location => 'Office', @owner => 'Jane'

    template = "{%subject%}[ ({%?Location=Office%}here[, {%cf_#{@owner.id}%}])]"

    assert_equal 'Computer (here, Jane)', render(template)
    assert_equal 'Mouse', render(template, @mouse)
  end

  # a condition is not a source of a value: a filled field next to it must not
  # keep the part alive on its own
  def test_a_condition_which_is_not_met_drops_its_part_despite_a_filled_field
    set_values @computer, @location => 'Storage', @owner => 'Jane'

    assert_equal 'Computer', render("{%subject%}[ ! {%?Location=Office%}{%cf_#{@owner.id}%}]")
  end

  def test_a_met_condition_alone_does_not_keep_a_part_whose_field_is_empty
    set_values @computer, @location => 'Office', @owner => ''

    assert_equal 'Computer', render("{%subject%}[ ! {%?Location=Office%}{%cf_#{@owner.id}%}]")
  end

  def test_a_part_with_a_met_condition_and_a_filled_field_stays
    set_values @computer, @location => 'Office', @owner => 'Jane'

    assert_equal 'Computer ! Jane', render("{%subject%}[ ! {%?Location=Office%}{%cf_#{@owner.id}%}]")
  end

  def test_every_condition_of_a_part_has_to_be_met
    template = "{%subject%}[ {%?cf_#{@platforms.id}=A%}{%?Location=Office%}here]"
    set_values @computer, @platforms => %w[A], @location => 'Storage'

    assert_equal 'Computer', render(template)

    set_values @computer, @location => 'Office'

    assert_equal 'Computer here', render(template)
  end

  def test_a_condition_prints_nothing_by_itself
    set_values @computer, @location => 'Office'

    assert_equal 'Computer ', render("{%subject%} {%?cf_#{@location.id}=Office%}")
  end

  def test_a_condition_reports_an_unknown_field
    error = assert_raises Additionals::FieldTemplate::Error do
      render '{%subject%}[ {%?Nowhere=Office%}here]'
    end

    assert_equal :error_field_template_unknown_placeholder, error.key
    assert_equal 'Nowhere', error.params[:name]
  end

  # join lines up what is there and drops the separator of what is not
  def test_join_puts_the_values_in_a_row
    set_values @computer, @owner => 'Jane', @year => '1996'

    assert_equal 'Computer (Jane, 1996)', render(join_template)
  end

  def test_join_leaves_out_the_separator_of_a_missing_value
    set_values @computer, @owner => 'Jane', @year => ''

    assert_equal 'Computer (Jane)', render(join_template)

    set_values @computer, @owner => '', @year => '1996'

    assert_equal 'Computer (1996)', render(join_template)
  end

  def test_a_part_with_an_empty_join_falls_away
    set_values @computer, @owner => '', @year => ''

    assert_equal 'Computer', render(join_template)
  end

  def test_join_takes_a_field_by_its_name_and_an_attribute
    set_values @computer, @owner => 'Jane'

    assert_equal 'Computer - Jane', render('{%join(" - ", subject, Owner)%}')
  end

  def test_join_takes_more_than_two_values
    set_values @computer, @owner => 'Jane', @year => '1996', @location => 'Office'

    assert_equal 'Jane/1996/Office',
                 render("{%join(\"/\", cf_#{@owner.id}, cf_#{@year.id}, cf_#{@location.id})%}")
  end

  def test_join_reports_an_unknown_function
    error = assert_raises Additionals::FieldTemplate::Error do
      render '{%first(", ", subject)%}'
    end

    assert_equal :error_field_template_unknown_function, error.key
    assert_equal 'first(", ", subject)', error.params[:name]
  end

  # without the quotes nobody could tell a separator from a field
  def test_join_reports_a_separator_which_is_not_quoted
    error = assert_raises Additionals::FieldTemplate::Error do
      render '{%join(subject, Owner)%}'
    end

    assert_equal :error_field_template_invalid_join, error.key
  end

  def test_join_reports_a_call_without_fields
    error = assert_raises Additionals::FieldTemplate::Error do
      render '{%join(", ")%}'
    end

    assert_equal :error_field_template_invalid_join, error.key
  end

  def test_join_reports_an_unknown_field
    error = assert_raises Additionals::FieldTemplate::Error do
      render '{%join(", ", Nowhere)%}'
    end

    assert_equal :error_field_template_unknown_placeholder, error.key
  end

  # a message about a value has to name the fields it is made of, in the words
  # a user knows them by
  def test_field_labels_names_the_fields_of_a_template
    labels = renderer.field_labels "{%subject%}[ ({%cf_#{@owner.id}%})][ - {%?cf_#{@location.id}%}fixed]"

    assert_equal [l(:field_subject), 'Owner', 'Location'], labels
  end

  def test_field_labels_names_a_field_of_a_condition_with_a_value
    labels = renderer.field_labels "{%subject%}[ {%?cf_#{@location.id}=Office%}here]"

    assert_equal [l(:field_subject), 'Location'], labels
  end

  def test_field_labels_lists_a_field_used_twice_only_once
    labels = renderer.field_labels "{%cf_#{@owner.id}%} {%cf_#{@owner.id}%}"

    assert_equal ['Owner'], labels
  end

  # a name the source reserves but does not allow in this template is refused,
  # printed or as a condition, instead of being cut down to nothing
  def test_a_reserved_placeholder_which_is_not_allowed_is_refused
    short = Additionals::FieldTemplate.new source(scope: :short)

    ['{%subject%} {%status%}', '{%subject%}[ ({%?status%})]'].each do |template|
      error = assert_raises Additionals::FieldTemplate::Error do
        short.render template, @computer
      end

      assert_equal :error_field_template_placeholder_not_allowed, error.key
      assert_equal 'status', error.params[:name]
    end
  end

  # the source turns an attribute off: it prints nothing and counts as empty
  def test_a_placeholder_the_source_turned_off_prints_nothing
    off = Additionals::FieldTemplate.new source(disabled: %w[project])

    assert_equal 'Computer', off.render('{%subject%}[ ({%project%})]', @computer)
    assert_equal 'Computer none', off.render('{%subject%}[ {%?project=none%}none]', @computer)
  end

  # a condition compares the key of the source, not the label which changes
  # with the language
  def test_a_condition_compares_the_value_the_source_names_for_it
    assert_equal "Computer #{@computer.status.name}", render('{%subject%} {%status%}')
    assert_equal 'Computer open', render('{%subject%}[ {%?status=open%}open]')
    assert_equal 'Computer', render('{%subject%}[ {%?status=closed%}closed]')
  end

  # A mark of a line has to be kept out of the formatter's reach, which counts
  # a markdown list on its own and loses every number but the first
  def test_marked_line_splits_off_a_mark_which_comes_from_a_placeholder
    set_values @computer, @position => '38'
    line = split_line "{%cf_#{@position.id}%}. {%subject%}"

    assert_equal '38.', line.mark
    assert_equal 'Computer', line.text
  end

  def test_marked_line_splits_off_a_mark_written_as_an_optional_part
    set_values @computer, @position => '38'
    line = split_line "[{%cf_#{@position.id}%}. ]{%subject%}"

    assert_equal '38.', line.mark
    assert_equal 'Computer', line.text
  end

  def test_marked_line_has_no_mark_where_the_record_has_no_number
    set_values @computer, @position => ''
    line = split_line "[{%cf_#{@position.id}%}. ]{%subject%}"

    assert_nil line.mark
    assert_equal 'Computer', line.text
  end

  # written down by hand, it asks for the list to be counted - which is what
  # the formatter does with it
  def test_marked_line_leaves_a_mark_of_fixed_text_alone
    line = split_line '1. {%subject%}'

    assert_nil line.mark
    assert_equal '1. Computer', line.text
  end

  def test_marked_reads_the_template_and_not_the_rendered_line
    assert renderer.marked? "{%cf_#{@position.id}%}. {%subject%}"
    assert_not renderer.marked? '1. {%subject%}'
    assert_not renderer.marked? '- {%subject%}'
    assert_not renderer.marked? '{%subject%}'
  end

  # A template is checked without fields, so a page can keep one for any list
  def test_check_syntax_accepts_unknown_placeholders_and_refuses_broken_syntax
    assert_nil Additionals::FieldTemplate.check_syntax('- {%Whatever%}[ {%?Other=A|B%}]')

    cases = { '- {%subject' => :error_field_template_placeholder_not_readable,
              '- {%subject%}[ {%Other%}' => :error_field_template_group_not_closed,
              '- {%?subject=%}' => :error_field_template_condition_without_value,
              '- {%joint(", ", a)%}' => :error_field_template_unknown_function }
    cases.each do |template, key|
      error = assert_raises(Additionals::FieldTemplate::Error, template) { Additionals::FieldTemplate.check_syntax template }

      assert_equal key, error.key, template
    end
  end

  # A template written by someone who sees a field still works for a reader
  # who does not, without telling what the field holds
  def test_a_field_the_reader_may_not_see_prints_nothing_and_counts_as_empty
    set_values @computer, @owner => 'Alice'
    renderer = Additionals::FieldTemplate.new IssueSource.new(@fields, hidden: [@owner])

    assert_equal '- Computer none', renderer.render('- {%subject%}[ {%Owner%}][ {%?Owner=Alice%}Alice][ {%?Owner=none%}none]', @computer)
  end

  # one query per referenced field instead of one per record and value, also
  # for a user who was deleted since
  def test_preload_references_loads_the_records_of_a_field_once
    deleted = issues :issues_003
    deleted.subject = 'Keyboard'
    set_values @computer, @assignee => users(:users_002).id.to_s
    set_values @mouse, @assignee => users(:users_003).id.to_s
    set_values deleted, @assignee => '999999'
    template = '- {%subject%}[ {%join(", ", Assignee)%}]'
    renderer = self.renderer
    renderer.preload_references [@computer, @mouse, deleted], template

    assert_no_queries_match(/\bFROM\W+users\b/) do
      assert_equal '- Computer John Smith', renderer.render(template, @computer)
      assert_equal '- Mouse Dave Lopper', renderer.render(template, @mouse)
      assert_equal '- Keyboard', renderer.render(template, deleted)
    end
  end

  # a renderer used for a record outside of the preloaded ones still prints it
  def test_a_reference_outside_of_the_preloaded_ones_is_cast_as_usual
    set_values @computer, @assignee => users(:users_002).id.to_s
    set_values @mouse, @assignee => users(:users_003).id.to_s
    renderer = self.renderer
    renderer.preload_references [@computer], '{%Assignee%}'

    assert_equal 'Dave Lopper', renderer.render('{%Assignee%}', @mouse)
  end

  # spaces around a name or a condition change nothing
  def test_spaces_around_a_placeholder_or_a_condition_are_ignored
    set_values @computer, @owner => 'Jane'

    assert_equal 'Jane ok', render('{% Owner %}[ {%? Owner = jane %}ok]')
  end

  private

  def source(**)
    IssueSource.new(@fields, **)
  end

  def renderer
    Additionals::FieldTemplate.new source
  end

  def render(template, issue = @computer)
    renderer.render template, issue
  end

  def split_line(template, issue = @computer)
    renderer.marked_line template, issue
  end

  def join_template
    "{%subject%}[ ({%join(\", \", cf_#{@owner.id}, cf_#{@year.id})%})]"
  end

  def build_field(name, format, **attributes)
    IssueCustomField.create!(name:, field_format: format, is_for_all: true, trackers: Tracker.all, **attributes)
  end

  # set in memory: a template reads the values of the record, not the database
  def set_values(issue, values)
    issue.custom_field_values = values.transform_keys { |field| field.id.to_s }
  end
end
