# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class ReportsControllerTest < Additionals::ControllerTest
  fixtures :users, :groups_users, :email_addresses, :user_preferences,
           :roles, :members, :member_roles,
           :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :issue_categories,
           :projects_trackers,
           :roles, :member_roles, :members,
           :enabled_modules, :workflows,
           :versions

  def setup
    prepare_tests
  end

  def test_get_issue_report_details_by_assignee_should_show_non_assigned_issue_count
    Issue.delete_all
    Issue.generate!
    Issue.generate!
    Issue.generate! status_id: 5
    Issue.generate! assigned_to_id: 2

    get :issue_report_details,
        params: { id: 1,
                  detail: 'assigned_to' }

    assert_select 'table.list tbody :last-child' do
      assert_select 'td', text: "[#{I18n.t :label_none}]"
      assert_select ':nth-child(2)', text: '2' # status:1
      assert_select ':nth-child(6)', text: '1' # status:5
      assert_select ':nth-child(8)', text: '2' # open
      assert_select ':nth-child(9)', text: '1' # closed
      assert_select ':nth-child(10)', text: '3' # total
    end
  end
end
