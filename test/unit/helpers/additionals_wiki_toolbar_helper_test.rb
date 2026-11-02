# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

# The textarea helpers of the wiki toolbar of Redmine 7.1 (https://www.redmine.org/issues/43259),
# which additionals brings to Redmine 7.0: plugins use them on both versions.
class AdditionalsWikiToolbarHelperTest < Additionals::HelperTest
  def setup
    super
    User.current = users :users_002
    @redmine_view = build_redmine_view IssuesController
    @issue = issues :issues_001
  end

  def test_wiki_textarea_tag_renders_the_textarea_with_its_toolbar
    with_settings text_formatting: 'common_mark' do
      html = @redmine_view.wiki_textarea_tag 'notes', 'Some text', preview_url: '/preview/notes'

      assert_select_in html, 'textarea#notes.wiki-edit[name=notes]', text: 'Some text'
      assert_wiki_toolbar 'notes', html, preview_url: '/preview/notes'
    end
  end

  def test_wiki_textarea_of_the_form_builder_renders_label_textarea_and_toolbar
    with_settings text_formatting: 'common_mark' do
      builder = Redmine::Views::LabelledFormBuilder.new :issue, @issue, @redmine_view, {}
      html = builder.wiki_textarea :description, rows: 5, preview_url: '/preview/issue'

      assert_select_in html, 'label[for=issue_description]'
      assert_select_in html, 'textarea#issue_description.wiki-edit[rows="5"][name=?]', 'issue[description]'
      assert_wiki_toolbar 'issue_description', html, preview_url: '/preview/issue'
    end
  end

  def test_custom_field_tag_with_label_renders_the_toolbar_of_a_full_text_field_on_request
    field = IssueCustomField.create! name: 'Long text', field_format: 'text', text_formatting: 'full',
                                     is_for_all: true, trackers: Tracker.all
    custom_value = @issue.custom_field_values.detect { |value| value.custom_field == field }
    field_id = "issue_custom_field_values_#{field.id}"

    with_settings text_formatting: 'common_mark' do
      html = @redmine_view.custom_field_tag_with_label :issue, custom_value, wiki_toolbar: true, preview_url: '/preview/cf'

      assert_wiki_toolbar field_id, html, preview_url: '/preview/cf'
      assert_not_includes @redmine_view.custom_field_tag_with_label(:issue, custom_value), 'jstBlock'
      assert_not_includes @redmine_view.custom_field_tag_with_label(:issue, custom_value), 'jsToolBar'
    end
  end
end
