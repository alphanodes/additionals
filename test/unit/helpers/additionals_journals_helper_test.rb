# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class AdditionalsJournalsHelperTest < Additionals::HelperTest
  include AdditionalsJournalsHelper
  include CustomFieldsHelper

  def test_email_custom_field_values_attributes_excludes_invisible_fields
    # role nobody in the test holds -> the hidden field is visible to no regular user
    restricted_role = Role.generate!
    hidden = IssueCustomField.generate! name: 'Hidden CF', field_format: 'string',
                                        is_for_all: true, visible: false, role_ids: [restricted_role.id],
                                        tracker_ids: Tracker.pluck(:id)
    shown = IssueCustomField.generate! name: 'Shown CF', field_format: 'string',
                                       is_for_all: true, visible: true, tracker_ids: Tracker.pluck(:id)
    issue = issues :issues_001
    issue.custom_field_values = { hidden.id => 'secret', shown.id => 'public info' }

    assert_save issue

    # non-admin user without a role that would unlock the hidden field
    User.current = users :users_002
    html = email_custom_field_values_attributes(issue, true).join

    assert_includes html, 'Shown CF'
    assert_not_includes html, 'Hidden CF'
  end
end
