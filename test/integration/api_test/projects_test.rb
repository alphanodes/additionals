# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

module ApiTest
  class ProjectsTest < Additionals::ApiTest
    fixtures :users, :email_addresses, :roles,
             :enumerations,
             :projects, :projects_trackers, :enabled_modules,
             :members, :member_roles,
             :issues, :issue_statuses, :issue_categories,
             :journals, :journal_details,
             :trackers,
             :attachments,
             :custom_fields, :custom_values,
             :time_entries,
             :dashboards, :dashboard_roles

    test 'GET /projects.xml should return projects' do
      get '/projects.xml',
          headers: credentials('jsmith')

      assert_response :success
      assert_equal 'application/xml', @response.media_type

      assert_select 'projects>project>id', text: '1'

      assert_select 'projects>project>enable_new_ticket_message'
      assert_select 'projects>project>new_ticket_message'
      assert_select 'projects>project>active_new_ticket_message'
    end

    test 'GET /projects/:id.xml should return the project' do
      get '/projects/1.xml',
          headers: credentials('jsmith')

      assert_response :success
      assert_equal 'application/xml', @response.media_type

      assert_select 'project>id', text: '1'
      assert_select 'project>status', text: '1'
      assert_select 'project>enable_new_ticket_message'
      assert_select 'project>new_ticket_message'
      assert_select 'project>active_new_ticket_message'
    end

    test 'GET /projects/:id.xml should return the project with active_new_ticket_message for all users' do
      get '/projects/1.xml'

      assert_response :success
      assert_equal 'application/xml', @response.media_type
      assert_select 'project>active_new_ticket_message'
    end
  end
end
