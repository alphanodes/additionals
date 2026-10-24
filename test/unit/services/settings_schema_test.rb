# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class SettingsSchemaTest < Additionals::TestCase
  RESET_DEFINITIONS = { query_id: { type: :enum, values: %w[1 2] }, own: { type: :boolean, reset_by: :query_id } }.freeze

  # A query class with an option beyond core: the statuses a board view shows
  # as its columns, stored in the serialized options of the query
  class BoardQuery < IssueQuery
    OPTIONS = {
      statuses: { type: :list,
                  label: :field_status,
                  values: ->(_schema) { IssueStatus.sorted.map { |status| [status.name, status.id.to_s] } },
                  applies: ->(schema) { schema.context[:query].display_type == 'board' } }
    }.freeze

    def available_display_types
      super + %w[board]
    end

    def options_schema(values = options[:board_options] || {})
      Additionals::SettingsSchema.new OPTIONS, values, query: self
    end
  end

  def setup
    prepare_tests
    User.current = users :users_002
  end

  def test_given_setting_that_does_not_apply_is_named
    definitions = { group: { type: :string }, interval: { type: :string, applies: ->(schema) { schema[:group] == 'date' } } }

    assert_equal [:interval], schema_for(definitions, group: 'tracker', interval: 'month').not_applied_keys
  end

  def test_given_setting_that_applies_is_not_named
    definitions = { group: { type: :string }, interval: { type: :string, applies: ->(schema) { schema[:group] == 'date' } } }

    assert_empty schema_for(definitions, group: 'date', interval: 'month').not_applied_keys
  end

  def test_rule_methods_are_named_after_the_setting
    object = Class.new { def interval_applies?(_schema) = false }.new
    definitions = Additionals::SettingsSchema.with_rule_methods({ interval: { type: :string } }, object)

    assert_equal :interval_applies?, definitions[:interval][:applies].name
  end

  def test_rule_methods_can_have_a_prefix
    object = Class.new { def query_option_interval_applies?(_schema) = false }.new
    definitions = Additionals::SettingsSchema.with_rule_methods({ interval: { type: :string } }, object, prefix: 'query_option_')

    assert definitions[:interval].key?(:applies)
  end

  def test_unknown_keys_are_dropped
    schema = schema_for({ title: { type: :string } }, title: 'Mine', chart: 'pie')

    assert_equal({ title: 'Mine' }, schema.settings)
  end

  def test_unknown_keys_are_reported_as_ignored
    schema = schema_for({ title: { type: :string } }, title: 'Mine', chart: 'pie')

    assert_equal [:chart], schema.ignored_keys
  end

  def test_string_keys_are_accepted
    schema = schema_for({ title: { type: :string } }, 'title' => 'Mine')

    assert_equal 'Mine', schema[:title]
  end

  def test_string_is_stripped
    assert_equal({ title: 'Mine' }, schema_for({ title: { type: :string } }, title: ' Mine ').settings)
  end

  def test_structure_for_a_single_value_is_rejected
    assert_includes schema_for({ title: { type: :string } }, title: { a: 1 }).errors, :title
  end

  def test_text_keeps_its_lines
    assert_equal "a\nb\n", schema_for({ text: { type: :text } }, text: "a\nb\n")[:text]
  end

  # A default from plugin settings is stored as text, e.g. "25"
  def test_default_of_a_number_given_as_text_reads_as_number
    assert_equal 25, Additionals::SettingsSchema.new({ days: { type: :integer, default: '25' } })[:days]
  end

  def test_stored_number_out_of_bounds_reads_as_default
    definitions = { days: { type: :integer, min: 1, max: 365, default: 7 } }

    assert_equal 7, Additionals::SettingsSchema.new(definitions, {}, stored: { days: '1000' })[:days]
  end

  def test_stored_number_in_bad_format_reads_as_default
    definitions = { days: { type: :integer, default: 7 } }

    assert_equal 7, Additionals::SettingsSchema.new(definitions, {}, stored: { days: 'abc' })[:days]
  end

  def test_boolean_from_form_value
    assert_equal({ on: '1' }, schema_for({ on: { type: :boolean } }, on: '1').settings)
  end

  def test_boolean_from_true_is_stored_like_the_form
    assert_equal({ on: '1' }, schema_for({ on: { type: :boolean } }, on: true).settings)
  end

  def test_boolean_from_false_is_stored_like_the_form
    assert_equal({ on: '0' }, schema_for({ on: { type: :boolean } }, on: false).settings)
  end

  def test_boolean_reads_as_boolean
    assert_equal true, schema_for({ on: { type: :boolean } }, on: '1')[:on] # rubocop:disable Minitest/AssertTruthy
  end

  def test_invalid_boolean_is_rejected
    assert_includes schema_for({ on: { type: :boolean } }, on: 'maybe').errors, :on
  end

  def test_integer_from_number_is_stored_like_the_form
    assert_equal({ max: '5' }, schema_for({ max: { type: :integer } }, max: 5).settings)
  end

  def test_integer_reads_as_integer
    assert_equal 5, schema_for({ max: { type: :integer } }, max: '5')[:max]
  end

  def test_integer_with_text_is_rejected
    assert_includes schema_for({ max: { type: :integer } }, max: 'abc').errors, :max
  end

  def test_integer_with_decimals_is_rejected
    assert_includes schema_for({ max: { type: :integer } }, max: '1.5').errors, :max
  end

  def test_blank_integer_is_kept_as_none
    assert_equal({ max: '' }, schema_for({ max: { type: :integer } }, max: '').settings)
  end

  def test_float_reads_as_float
    assert_in_delta 2.5, schema_for({ share: { type: :float } }, share: '2.5')[:share]
  end

  def test_number_above_max_is_rejected
    assert_includes schema_for({ share: { type: :float, max: 100 } }, share: '100.1').errors, :share
  end

  def test_number_below_min_is_rejected
    assert_includes schema_for({ max: { type: :integer, min: 1 } }, max: '0').errors, :max
  end

  def test_date_reads_as_date
    assert_equal Date.new(2022, 6, 4), schema_for({ from: { type: :date } }, from: ' 2022-06-04 ')[:from]
  end

  # Stored as the date fields send it, no other format and no day that does not exist
  def test_date_in_another_format_or_of_no_day_is_rejected
    %w[04.06.2022 2022-02-30 2022-6-4 today].each do |value|
      assert_includes schema_for({ from: { type: :date } }, from: value).errors, :from, value
    end
  end

  def test_stored_date_in_bad_format_reads_as_default
    definitions = { from: { type: :date, default: Date.new(2022, 1, 1) } }

    assert_equal Date.new(2022, 1, 1), Additionals::SettingsSchema.new(definitions, {}, stored: { from: 'x' })[:from]
  end

  # A bound may depend on another setting, e.g. the end of a period on its start
  def test_date_before_its_min_is_rejected
    definitions = { from: { type: :date }, to: { type: :date, min: ->(schema) { schema[:from] } } }

    assert_includes schema_for(definitions, from: '2022-06-04', to: '2022-06-03').errors, :to
    assert_empty schema_for(definitions, from: '2022-06-04', to: '2022-06-04').errors
    assert_equal '2022-06-04', schema_for(definitions, from: '2022-06-04', to: '').describe.last[:min]
  end

  def test_enum_value_out_of_values_is_rejected
    assert_includes schema_for({ type: { type: :enum, values: %w[pie bar] } }, type: 'line').errors, :type
  end

  def test_enum_value_of_values_is_valid
    assert_predicate schema_for({ type: { type: :enum, values: %w[pie bar] } }, type: 'bar'), :valid?
  end

  # A program names a query instead of giving its id
  def test_enum_value_given_by_its_label_is_stored_as_value
    schema = schema_for({ query_id: { type: :enum, values: [%w[Open 5], %w[Closed 6]] } }, query_id: 'closed')

    assert_equal({ query_id: '6' }, schema.settings)
  end

  def test_label_used_twice_is_rejected
    schema = schema_for({ query_id: { type: :enum, values: [%w[Open 5], %w[Open 7]] } }, query_id: 'Open')

    assert_includes schema.errors, :query_id
  end

  def test_value_wins_over_a_label
    schema = schema_for({ query_id: { type: :enum, values: [%w[5 6], %w[Six 5]] } }, query_id: '5')

    assert_equal({ query_id: '5' }, schema.settings)
  end

  def test_list_entries_given_by_their_label_are_stored_as_values
    schema = schema_for({ columns: { type: :list, values: [%w[Subject subject], %w[Status status]] } },
                        columns: %w[Status subject])

    assert_equal({ columns: %w[status subject] }, schema.settings)
  end

  def test_blank_enum_means_none
    assert_predicate schema_for({ type: { type: :enum, values: %w[pie bar] } }, type: ''), :valid?
  end

  def test_list_drops_blank_entries_of_the_form
    assert_equal({ columns: %w[subject status] },
                 schema_for({ columns: { type: :list } }, columns: ['', 'subject', 'status']).settings)
  end

  def test_list_entry_out_of_values_is_rejected
    schema = schema_for({ columns: { type: :list, values: %w[subject] } }, columns: %w[subject secret])

    assert_includes schema.errors, :columns
  end

  def test_missing_required_setting_is_rejected
    assert_includes schema_for({ url: { type: :string, required: true } }, {}).errors, :url
  end

  def test_blank_required_setting_is_rejected
    assert_includes schema_for({ url: { type: :string, required: true } }, url: ' ').errors, :url
  end

  def test_stored_value_is_not_checked_again
    schema = Additionals::SettingsSchema.new({ type: { type: :enum, values: %w[pie] }, title: { type: :string } },
                                             { title: 'Mine' }, stored: { type: 'gone' })

    assert_predicate schema, :valid?
  end

  # E.g. a private query of another user the editor cannot choose
  def test_stored_choice_sent_back_unchanged_is_valid
    schema = Additionals::SettingsSchema.new({ query_id: { type: :enum, values: %w[1 2] } }, { query_id: '9' },
                                             stored: { query_id: '9' })

    assert_predicate schema, :valid?
  end

  def test_other_choice_than_the_stored_one_is_checked
    schema = Additionals::SettingsSchema.new({ query_id: { type: :enum, values: %w[1 2] } }, { query_id: '8' },
                                             stored: { query_id: '9' })

    assert_includes schema.errors, :query_id
  end

  def test_stored_list_entries_sent_back_are_valid
    schema = Additionals::SettingsSchema.new({ ids: { type: :list, values: %w[1 2] } }, { ids: %w[1 9] },
                                             stored: { ids: %w[9] })

    assert_predicate schema, :valid?
  end

  def test_change_of_the_reset_by_setting_drops_the_stored_value
    schema = Additionals::SettingsSchema.new(RESET_DEFINITIONS, { query_id: '2' }, stored: { query_id: '1', own: '1' })

    assert_equal({ query_id: '2' }, schema.settings)
  end

  def test_change_of_the_reset_by_setting_ignores_a_given_value
    schema = Additionals::SettingsSchema.new(RESET_DEFINITIONS, { query_id: '2', own: '1' }, stored: { query_id: '1' })

    assert_equal [:own], schema.not_applied_keys
  end

  def test_unchanged_reset_by_setting_keeps_the_stored_value
    schema = Additionals::SettingsSchema.new(RESET_DEFINITIONS, { query_id: '1' }, stored: { query_id: '1', own: '1' })

    assert_equal({ query_id: '1', own: '1' }, schema.settings)
  end

  # A new block sets both at once
  def test_first_value_of_the_reset_by_setting_keeps_a_given_value
    schema = Additionals::SettingsSchema.new(RESET_DEFINITIONS, { query_id: '1', own: '1' })

    assert_equal({ query_id: '1', own: '1' }, schema.settings)
  end

  def test_change_of_the_reset_by_setting_drops_a_stored_secret_and_keeps_a_given_one
    definitions = { url: { type: :string }, token: { type: :string, secret: true, reset_by: :url } }
    stored = { url: 'https://example.org', token: 'old' }
    cases = { { url: 'https://example.net' } => { url: 'https://example.net' },
              { url: 'https://example.net', token: 'new' } => { url: 'https://example.net', token: 'new' } }

    cases.each do |values, expected|
      schema = Additionals::SettingsSchema.new(definitions, values, stored:)

      assert_equal expected, schema.settings, values.inspect
      assert_empty schema.not_applied_keys, values.inspect
    end
  end

  def test_description_names_the_dependencies_of_a_setting
    definitions = { own: { type: :boolean }, columns: { type: :list, shown_with: :own, reset_by: :own } }
    columns = Additionals::SettingsSchema.new(definitions).describe.find { |setting| setting[:key] == :columns }

    assert_equal %i[own own], columns.values_at(:shown_with, :reset_by)
  end

  def test_stored_value_completes_the_given_ones
    schema = Additionals::SettingsSchema.new({ type: { type: :enum, values: %w[pie] }, title: { type: :string } },
                                             { title: 'Mine' }, stored: { type: 'pie' })

    assert_equal({ type: 'pie', title: 'Mine' }, schema.settings)
  end

  # A rule can keep a stored value valid that would no longer be offered
  def test_stored_value_stays_readable_beside_a_given_one
    definitions = { days: { type: :integer } }

    assert_equal '5', Additionals::SettingsSchema.new(definitions, { days: '9' }, stored: { days: '5' }).stored(:days)
  end

  def test_given_value_replaces_the_stored_one
    schema = Additionals::SettingsSchema.new({ type: { type: :enum, values: %w[pie bar] } }, { type: 'bar' }, stored: { type: 'pie' })

    assert_equal 'bar', schema[:type]
  end

  def test_missing_required_setting_is_rejected_although_stored_blank
    schema = Additionals::SettingsSchema.new({ url: { type: :string, required: true }, title: { type: :string } },
                                             { title: 'Mine' }, stored: { url: '' })

    assert_includes schema.errors, :url
  end

  # The default fills a required setting nobody gave, like the form shows it
  def test_missing_required_setting_with_a_default_is_valid
    assert_predicate schema_for({ max: { type: :integer, required: true, default: 10 } }, {}), :valid?
  end

  def test_required_setting_with_a_default_stored_blank_is_valid
    schema = Additionals::SettingsSchema.new({ max: { type: :integer, required: true, default: 10 }, title: { type: :string } },
                                             { title: 'Mine' }, stored: { max: '' })

    assert_predicate schema, :valid?
  end

  def test_required_setting_with_a_default_given_blank_is_rejected
    assert_includes schema_for({ max: { type: :integer, required: true, default: 10 } }, max: '').errors, :max
  end

  def test_missing_required_setting_with_a_default_of_a_rule_is_valid
    assert_predicate schema_for({ max: { type: :integer, required: true, default: ->(_schema) { 10 } } }, {}), :valid?
  end

  def test_secret_is_described_without_its_value
    schema = schema_for({ token: { type: :string, secret: true } }, token: 'abc')

    assert_equal({ key: :token, type: :string, label: 'Token', applies: true, secret: true }, schema.describe.first)
  end

  def test_placeholder_is_described_as_text
    schema = schema_for({ title: { type: :string, placeholder: :label_news_latest } }, {})

    assert_equal I18n.t(:label_news_latest), schema.describe.first[:placeholder]
  end

  def test_info_can_be_a_rule_method
    object = Class.new { def url_info(_schema) = 'Address of the feed' }.new
    definitions = Additionals::SettingsSchema.with_rule_methods({ url: { type: :string } }, object)

    assert_equal 'Address of the feed', schema_for(definitions, {}).describe.first[:description]
  end

  # Programs get the text of an info with a link
  def test_html_info_is_described_as_text
    schema = schema_for({ token: { type: :string, info: 'Create it at <a href="https://example.org">example</a>.'.html_safe } }, {})

    assert_equal 'Create it at example.', schema.describe.first[:description]
  end

  # A form shows its link
  def test_html_info_is_kept_for_a_form
    info = 'Create it at <a href="https://example.org">example</a>.'.html_safe
    schema = schema_for({ token: { type: :string, info: } }, {})

    assert_equal info, schema.describe(html: true).first[:description]
  end

  # Only an info marked as HTML safe is HTML, other text stays as it is
  def test_text_info_is_not_sanitized
    schema = schema_for({ hosts: { type: :string, info: 'Hosts, e.g. <name>' } }, {})

    assert_equal 'Hosts, e.g. <name>', schema.describe.first[:description]
  end

  def test_default_is_read_for_a_missing_setting
    assert_equal 10, schema_for({ max: { type: :integer, default: 10 } }, {})[:max]
  end

  def test_default_is_read_for_a_blank_setting
    assert_equal 10, schema_for({ max: { type: :integer, default: 10 } }, max: '')[:max]
  end

  def test_default_is_not_stored
    assert_empty schema_for({ max: { type: :integer, default: 10 } }, {}).settings
  end

  def test_values_depend_on_other_settings
    definitions = { kind: { type: :enum, values: %w[fruit] },
                    name: { type: :enum, values: ->(schema) { schema[:kind] == 'fruit' ? %w[apple] : [] } } }

    assert_predicate schema_for(definitions, kind: 'fruit', name: 'apple'), :valid?
  end

  def test_values_depend_on_the_context
    definitions = { project: { type: :enum, values: ->(schema) { [schema.context[:project].identifier] } } }
    schema = Additionals::SettingsSchema.new definitions, { project: 'ecookbook' }, project: projects(:projects_001)

    assert_predicate schema, :valid?
  end

  def test_setting_unavailable_in_the_context_is_ignored
    definitions = { secret: { type: :string, if: ->(_schema) { false } } }

    assert_equal [:secret], schema_for(definitions, secret: 'x').ignored_keys
  end

  def test_setting_that_does_not_apply_is_kept
    definitions = { kind: { type: :enum, values: %w[date status] },
                    interval: { type: :enum, values: %w[month], applies: ->(schema) { schema[:kind] == 'date' } } }

    assert_equal({ kind: 'status', interval: 'month' }, schema_for(definitions, kind: 'status', interval: 'month').settings)
  end

  def test_required_setting_that_does_not_apply_may_be_missing
    definitions = { url: { type: :string, required: true, applies: ->(_schema) { false } } }

    assert_predicate schema_for(definitions, {}), :valid?
  end

  def test_invalid_value_is_rejected_although_it_does_not_apply
    definitions = { interval: { type: :enum, values: %w[month], applies: ->(_schema) { false } } }

    assert_includes schema_for(definitions, interval: 'decade').errors, :interval
  end

  def test_error_messages_name_the_setting
    schema = schema_for({ url: { type: :string, label: :field_url, required: true } }, {})

    assert_equal ["#{::I18n.t :field_url} #{::I18n.t 'activerecord.errors.messages.blank'}"], schema.full_messages
  end

  def test_unknown_type_raises
    assert_raises ArgumentError do
      schema_for({ title: { type: :color } }, {})
    end
  end

  def test_unknown_option_raises
    assert_raises ArgumentError do
      schema_for({ title: { type: :string, maximum: 3 } }, {})
    end
  end

  def test_describe_settings
    definitions = { max: { type: :integer, label: :label_max_entries, info: :info_chart_max_entries,
                           min: 1, max: 100, default: 10, required: true } }

    assert_equal [{ key: :max, type: :integer, label: ::I18n.t(:label_max_entries),
                    description: ::I18n.t(:info_chart_max_entries), required: true, default: 10,
                    min: 1, max: 100, applies: true, value: 5 }],
                 schema_for(definitions, max: '5').describe
  end

  def test_describe_values_with_labels
    definitions = { status: { type: :enum, values: [%w[New 1], %w[Closed 5]] } }

    assert_equal [{ value: '1', label: 'New' }, { value: '5', label: 'Closed' }],
                 schema_for(definitions, {}).describe.first[:values]
  end

  def test_describe_values_without_labels
    assert_equal [{ value: 'pie', label: 'pie' }],
                 schema_for({ type: { type: :enum, values: %w[pie] } }, {}).describe.first[:values]
  end

  def test_describe_whether_a_setting_applies
    definitions = { interval: { type: :enum, values: %w[month], applies: ->(_schema) { false } } }

    assert_not schema_for(definitions, {}).describe.first[:applies]
  end

  def test_describe_skips_unavailable_settings
    assert_empty schema_for({ secret: { type: :string, if: ->(_schema) { false } } }, {}).describe
  end

  def test_describe_is_serializable
    definitions = { status: { type: :enum, label: ->(_schema) { 'Status' },
                              values: ->(_schema) { [%w[New 1]] } } }

    assert_equal 'Status', JSON.parse(schema_for(definitions, {}).describe.to_json).first['label']
  end

  def test_query_option_applies_to_its_display_type
    query = BoardQuery.new name: '_', display_type: 'board'

    assert query.options_schema(statuses: [IssueStatus.first.id.to_s]).describe.first[:applies]
  end

  def test_query_option_does_not_apply_to_another_display_type
    query = BoardQuery.new name: '_', display_type: 'list'

    assert_not query.options_schema.describe.first[:applies]
  end

  def test_query_option_rejects_an_unknown_value
    query = BoardQuery.new name: '_', display_type: 'board'

    assert_includes query.options_schema(statuses: ['0']).errors, :statuses
  end

  def test_query_option_is_stored_outside_the_filters
    query = BoardQuery.new name: '_', display_type: 'board'
    query.options[:board_options] = query.options_schema(statuses: ['', IssueStatus.first.id.to_s]).settings

    assert_equal [IssueStatus.first.id.to_s], query.options_schema[:statuses]
  end

  private

  def schema_for(definitions, values)
    Additionals::SettingsSchema.new definitions, values
  end
end
