# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

module ApiTest
  class IssuesTest < Redmine::ApiTest::Base
    fixtures :projects,
             :users,
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
             :time_entries,
             :journals,
             :journal_details,
             :queries

    include Additionals::TestHelper

    test 'GET /issues.xml should contain metadata' do
      get '/issues.xml'
      assert_select 'issues[type=array][total_count][limit="25"][offset="0"]'
    end

    test 'GET /issues/:id.xml with subtasks' do
      issue = Issue.generate_with_descendants! project_id: 1
      get "/issues/#{issue.id}.xml?include=children"

      assert_select 'issue id', text: issue.id.to_s do
        assert_select '~ children[type=array] > issue', 2
        assert_select '~ children[type=array] > issue > children', 1
      end
    end

    test 'POST /issues.xml should create an issue with the attributes' do
      with_additionals_settings(issue_status_change: '0',
                                issue_auto_assign: '0',
                                issue_auto_assign_status: ['1'],
                                issue_auto_assign_role: '1') do
        payload = <<-XML
        <?xml version="1.0" encoding="UTF-8" ?>
        <issue>
          <project_id>1</project_id>
          <tracker_id>2</tracker_id>
          <status_id>3</status_id>
          <subject>API test</subject>
        </issue>
        XML

        assert_difference 'Issue.count' do
          post '/issues.xml',
               params: payload,
               headers: { 'CONTENT_TYPE' => 'application/xml' }.merge(credentials('jsmith'))
        end
        issue = Issue.order(id: :desc).first
        assert_equal 1, issue.project_id
        assert_nil issue.assigned_to_id
        assert_equal 'API test', issue.subject

        assert_response :created
        assert_equal 'application/xml', @response.media_type
        assert_select 'issue > id', text: issue.id.to_s
      end
    end

    test 'POST /issues.xml should create an issue with auto assigned_to_id' do
      with_additionals_settings(issue_status_change: '0',
                                issue_auto_assign: '1',
                                issue_auto_assign_status: ['1'],
                                issue_auto_assign_role: '1') do
        payload = <<-XML
        <?xml version="1.0" encoding="UTF-8" ?>
        <issue>
          <project_id>1</project_id>
          <subject>API test</subject>
        </issue>
        XML

        assert_difference 'Issue.count' do
          post '/issues.xml',
               params: payload,
               headers: { 'CONTENT_TYPE' => 'application/xml' }.merge(credentials('jsmith'))
        end

        issue = Issue.order(id: :desc).first
        assert_equal 1, issue.project_id
        assert_equal 2, issue.assigned_to_id
        assert_equal 'API test', issue.subject

        assert_response :created
        assert_equal 'application/xml', @response.media_type
        assert_select 'issue > id', text: issue.id.to_s
      end
    end

    test 'DELETE /issues/:id.xml' do
      assert_difference('Issue.count', -1) do
        delete '/issues/6.xml', headers: credentials('jsmith')

        assert_response :success
        assert_equal '', response.body
      end
      assert_nil Issue.find_by(id: 6)
    end
  end
end
