# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class ApplicationHelperTest < Additionals::HelperTest
  def setup
    super
    User.current = users :users_002
    @redmine_view = build_redmine_view IssuesController
    @issue = issues :issues_001
    @redmine_view.instance_variable_set :@issue, @issue
  end

  def test_principals_options_for_select_lists_the_author_of_the_latest_note_as_involved
    note_author = users :users_003
    Journal.create! journalized: @issue, user: note_author, notes: 'Latest note'

    assert_includes involved_principals_optgroup, %(value="#{note_author.id}")
  end

  def test_principals_options_for_select_ignores_journals_without_notes
    detail_author = users :users_004
    Journal.create! journalized: @issue, user: detail_author, notes: ''

    assert_not_includes involved_principals_optgroup, %(value="#{detail_author.id}")
  end

  private

  def involved_principals_optgroup
    html = @redmine_view.principals_options_for_select @issue.assignable_users
    html[%r{<optgroup label="#{Regexp.escape ERB::Util.h(l(:label_involved_principals))}">.*?</optgroup>}m].to_s
  end
end
