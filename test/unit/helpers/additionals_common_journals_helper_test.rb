# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

# The author badge of a note says the same for every kind of entry, so any
# entry with an author shows it without a text of its own
class AdditionalsCommonJournalsHelperTest < Additionals::HelperTest
  def setup
    super
    @redmine_view = build_redmine_view IssuesController
  end

  def test_author_indicator_names_no_entity
    [issues(:issues_001), messages(:messages_001)].each do |entry|
      html = @redmine_view.render_author_indicator entry, Journal.new(user_id: entry.author_id)

      assert_select_in html, 'span.badge-author[title=?]', l(:label_user_is_author_of)
    end
  end

  def test_author_indicator_only_for_notes_of_the_author
    issue = issues :issues_001

    assert_nil @redmine_view.render_author_indicator(issue, Journal.new(user_id: issue.author_id + 1))
  end
end
