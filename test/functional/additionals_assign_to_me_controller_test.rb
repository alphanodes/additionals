# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsAssignToMeControllerTest < Additionals::ControllerTest
  fixtures :projects,
           :users, :email_addresses, :user_preferences,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :issue_relations,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :attachments,
           :workflows,
           :custom_fields,
           :custom_values,
           :custom_fields_projects,
           :custom_fields_trackers,
           :time_entries,
           :journals,
           :journal_details,
           :queries

  test 'assign issue to user' do
    session[:user_id] = 2
    assert_difference 'Journal.count' do
      put :update,
          params: { issue_id: 1 }
    end
  end

  test 'no update for issue, which already same user is assigned' do
    session[:user_id] = 3
    assert_no_difference 'Journal.count' do
      put :update,
          params: { issue_id: 2 }
    end
  end
end
