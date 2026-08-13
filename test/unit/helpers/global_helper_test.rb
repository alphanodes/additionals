# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class GlobalHelperTest < Additionals::HelperTest
  include Additionals::Helpers
  include RedminePluginKit::Helpers::GlobalHelper
  include AdditionalsMenuHelper
  include CustomFieldsHelper
  include AvatarsHelper
  include Redmine::I18n
  include ERB::Util

  def test_custom_field_value_with_single_value
    field = IssueCustomField.generate! name: 'Height'
    value = CustomFieldValue.new
    value.custom_field = field
    value.value = '20'

    assert custom_field_value?(value)
  end

  def test_custom_field_value_without_value
    field = IssueCustomField.generate! name: 'Height'
    value = CustomFieldValue.new
    value.custom_field = field
    value.value = ''

    assert_not custom_field_value?(value)
  end

  # A multi value field without any value arrives as [nil]. That is present?, so a
  # plain check would render a label without a value.
  def test_custom_field_value_for_multi_value_field_without_value
    field = IssueCustomField.generate! name: 'Orientation', field_format: 'list',
                                       multiple: true, possible_values: %w[North South]
    value = CustomFieldValue.new
    value.custom_field = field
    value.value = [nil]

    assert_not custom_field_value?(value)
  end

  def test_custom_field_value_for_multi_value_field_with_values
    field = IssueCustomField.generate! name: 'Orientation', field_format: 'list',
                                       multiple: true, possible_values: %w[North South]
    value = CustomFieldValue.new
    value.custom_field = field
    value.value = [nil, 'North']

    assert custom_field_value?(value)
  end

  def test_attribute_label_with_text
    assert_equal '<span class="label">Height:</span>', attribute_label('Height')
  end

  def test_attribute_label_with_locale_key
    assert_equal "<span class=\"label\">#{l :field_subject}:</span>", attribute_label(:field_subject)
  end

  # A custom field brings its description along, shown as tooltip the way Redmine
  # does it for issue attributes.
  def test_attribute_label_with_custom_field_description
    field = IssueCustomField.generate! name: 'Height', description: 'In meters'
    html = attribute_label field

    assert_include 'title="In meters"', html
    assert_include 'class="label field-description"', html
    assert_include 'Height:', html
  end

  def test_attribute_label_with_custom_field_without_description
    field = IssueCustomField.generate! name: 'Height'

    assert_equal '<span class="label">Height:</span>', attribute_label(field)
  end

  def test_attribute_label_with_explicit_title
    assert_include 'title="own hint"', attribute_label('Height', title: 'own hint')
  end

  def test_user_with_avatar
    html = user_with_avatar users(:users_001)

    assert_include 'Redmine Admin', html
  end

  def test_link_to_url
    assert_equal 'redmine.org/test', Nokogiri::HTML.parse(link_to_url('http://redmine.org/test')).xpath('//a').first.text
    assert_equal 'redmine.org/test', Nokogiri::HTML.parse(link_to_url('https://redmine.org/test')).xpath('//a').first.text
  end

  def test_autocomplete_select_entries_keeps_blank_option_for_single
    html = autocomplete_select_entries 'foo', 'assignee_auto_completes', nil,
                                       multiple: false, include_blank: true

    assert_match(/<option value=""/, html)
  end

  def test_autocomplete_select_entries_omits_blank_option_for_multiple
    html = autocomplete_select_entries 'foo', 'assignee_auto_completes', nil,
                                       multiple: true, include_blank: true

    assert_no_match(/<option value=""/, html)
    assert_match(/<input[^>]*type="hidden"[^>]*name="foo\[\]"/, html)
  end

  def test_autocomplete_select_entries_hidden_field_does_not_double_bracket_array_name
    html = autocomplete_select_entries 'foo[]', 'assignee_auto_completes', nil,
                                       multiple: true, include_blank: true

    assert_match(/<input[^>]*type="hidden"[^>]*name="foo\[\]"/, html)
    assert_no_match(/name="foo\[\]\[\]"/, html)
  end

  # The select2 ajax url is interpolated into a JS string literal. HTML escaping
  # would turn the "&" between query parameters into "&amp;", so everything
  # behind the first parameter would arrive as part of its value.
  def test_autocomplete_select_entries_keeps_ampersand_in_ajax_url
    html = autocomplete_select_entries 'foo', 'assignee_auto_completes', nil,
                                       multiple: false,
                                       ajax_params: { with_me: true, active_only: true }

    assert_match(/url: "[^"]*active_only=true&with_me=true/, html)
    assert_no_match(/url: "[^"]*&amp;/, html)
  end

  def test_render_label_sum_keeps_html_safe_label_intact
    result = render_label_sum '<a href="/x">file</a>'.html_safe, '1 KB'

    assert_predicate result, :html_safe?
    assert_includes result, '<a href="/x">file</a>'
  end

  def test_entity_mail_attachments_returns_all_without_journal
    issue = issues :issues_001
    attachment = Attachment.create! container: issue,
                                    file: uploaded_test_file('testfile.txt', 'text/plain'),
                                    author: users(:users_001)

    assert_includes entity_mail_attachments(issue.reload, nil), attachment
  end

  def test_entity_mail_attachments_returns_only_journal_added
    issue = issues :issues_001
    added = Attachment.create! container: issue,
                               file: uploaded_test_file('testfile.txt', 'text/plain'),
                               author: users(:users_001)
    other = Attachment.create! container: issue,
                               file: uploaded_test_file('testfile.txt', 'text/plain'),
                               author: users(:users_001)
    journal = Journal.create! journalized: issue, user: users(:users_001)
    journal.details.create! property: 'attachment', prop_key: added.id.to_s, value: added.filename

    result = entity_mail_attachments issue.reload, journal

    assert_includes result, added
    assert_not_includes result, other
  end

  def test_entity_mail_attachments_empty_when_journal_has_no_attachment_detail
    issue = issues :issues_001
    Attachment.create! container: issue,
                       file: uploaded_test_file('testfile.txt', 'text/plain'),
                       author: users(:users_001)
    journal = Journal.create! journalized: issue, user: users(:users_001), notes: 'note only'

    assert_empty entity_mail_attachments(issue.reload, journal)
  end
end
