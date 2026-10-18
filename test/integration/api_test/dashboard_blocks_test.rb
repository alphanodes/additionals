# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

module ApiTest
  # Dashboard blocks for programs, computed with the settings of the request
  class DashboardBlocksTest < Additionals::ApiTest
    test 'GET /dashboard_blocks.json lists the blocks of the welcome page' do
      get '/dashboard_blocks.json', headers: credentials('admin')

      assert_includes block_ids, 'news'
    end

    test 'GET /dashboard_blocks.json leaves out blocks of projects' do
      get '/dashboard_blocks.json', headers: credentials('admin')

      assert_not_includes block_ids, 'projectissues'
    end

    test 'GET /projects/:id/dashboard_blocks.json lists the blocks of the project' do
      get '/projects/ecookbook/dashboard_blocks.json', headers: credentials('admin')

      assert_includes block_ids, 'projectissues'
    end

    test 'GET /dashboard_blocks.json describes the settings of a block' do
      get '/dashboard_blocks.json', headers: credentials('admin')

      assert_equal({ 'key' => 'max_entries', 'type' => 'integer', 'min' => 1, 'max' => 100, 'default' => 10 },
                   listed_block('feed')['settings'].detect { |setting| setting['key'] == 'max_entries' }.except('label', 'applies'))
    end

    test 'GET /dashboard_blocks.json tells which blocks export data' do
      get '/dashboard_blocks.json', headers: credentials('admin')

      assert_equal [true, false], [listed_block('news')['exports_data'], listed_block('welcome')['exports_data']]
    end

    test 'GET /dashboard_blocks.json leaves out blocks the user may not use' do
      get '/projects/ecookbook/dashboard_blocks.json', headers: credentials('jsmith')
      allowed = block_ids
      Role.find(1).remove_permission! :view_news

      get '/projects/ecookbook/dashboard_blocks.json', headers: credentials('jsmith')

      assert_equal ['news'], allowed - block_ids
    end

    test 'GET /dashboard_blocks/:id.json returns the data of the block' do
      get '/dashboard_blocks/news.json', params: { settings: { max_entries: '2' } }, headers: credentials('admin')

      assert_equal News.latest(users(:users_001), 2).map(&:title), json_block['data'].pluck('title')
    end

    test 'GET /dashboard_blocks/:id.json returns the typed settings' do
      get '/dashboard_blocks/news.json', params: { settings: { max_entries: '2' } }, headers: credentials('admin')

      assert_equal({ 'max_entries' => 2 }, json_block['settings'])
    end

    test 'GET /dashboard_blocks/:id.json reads defaults of missing settings' do
      get '/dashboard_blocks/news.json', headers: credentials('admin')

      assert_equal({ 'max_entries' => DashboardContent::DEFAULT_MAX_ENTRIES }, json_block['settings'])
    end

    test 'GET /projects/:id/dashboard_blocks/:id.json returns the data of the project' do
      get '/projects/ecookbook/dashboard_blocks/news.json', headers: credentials('admin')

      assert_equal [projects(:projects_001).name], json_block['data'].pluck('project').uniq
    end

    test 'GET /dashboard_blocks/:id.json lists the entries of a query' do
      query = IssueQuery.create! name: 'All issues', visibility: Query::VISIBILITY_PUBLIC, user: users(:users_001),
                                 filters: { 'status_id' => { operator: '*', values: [''] } }

      get '/dashboard_blocks/issuequery.json', params: { settings: { query_id: query.id, max_entries: 3 } },
                                               headers: credentials('admin')

      assert_equal 3, json_block['data']['rows'].size
    end

    test 'GET /dashboard_blocks/:id.json returns text as written' do
      get '/dashboard_blocks/text.json', params: { settings: { title: 'Hello', text: 'Some *text*' } },
                                         headers: credentials('admin')

      assert_equal({ 'title' => 'Hello', 'text' => 'Some *text*' }, json_block['data'])
    end

    test 'GET /dashboard_blocks/:id.json returns no data of a block without export' do
      get '/dashboard_blocks/welcome.json', headers: credentials('admin')

      assert_nil json_block['data']
    end

    test 'GET /dashboard_blocks/:id.json rejects invalid settings' do
      get '/dashboard_blocks/news.json', params: { settings: { max_entries: '5000' } }, headers: credentials('admin')

      assert_response :unprocessable_content
    end

    test 'GET /dashboard_blocks/:id.json names the invalid setting' do
      get '/dashboard_blocks/news.json', params: { settings: { max_entries: '5000' } }, headers: credentials('admin')

      assert_match I18n.t(:label_max_entries), response.parsed_body['errors'].first
    end

    test 'GET /dashboard_blocks/:id.json requires the settings a block needs' do
      get '/dashboard_blocks/issuequery.json', headers: credentials('admin')

      assert_response :unprocessable_content
    end

    test 'GET /dashboard_blocks/:id.json rejects an unknown setting' do
      get '/dashboard_blocks/news.json', params: { settings: { max_entry: '5' } }, headers: credentials('admin')

      assert_response :unprocessable_content
    end

    test 'GET /dashboard_blocks/:id.json names the unknown setting' do
      get '/dashboard_blocks/news.json', params: { settings: { max_entry: '5' } }, headers: credentials('admin')

      assert_match(/\Amax_entry /, response.parsed_body['errors'].first)
    end

    # Subprojects only exist on a project dashboard
    test 'GET /dashboard_blocks/:id.json rejects a setting the block does not have without a project' do
      get '/dashboard_blocks/news.json', params: { settings: { with_subprojects: '1' } }, headers: credentials('admin')

      assert_response :unprocessable_content
    end

    test 'GET /projects/:id/dashboard_blocks/:id.json accepts a setting the block has with a project' do
      get '/projects/ecookbook/dashboard_blocks/news.json', params: { settings: { with_subprojects: '1' } },
                                                            headers: credentials('admin')

      assert_response :success
    end

    test 'GET /dashboard_blocks/:id.json of an unknown block is not found' do
      get '/dashboard_blocks/unknown.json', headers: credentials('admin')

      assert_response :not_found
    end

    test 'GET /dashboard_blocks/:id.json of a block of projects is not found on the welcome page' do
      get '/dashboard_blocks/projectissues.json', headers: credentials('admin')

      assert_response :not_found
    end

    test 'GET /dashboard_blocks/:id.json of a block without permission is not found' do
      Role.find(1).remove_permission! :view_news

      get '/projects/ecookbook/dashboard_blocks/news.json', headers: credentials('jsmith')

      assert_response :not_found
    end

    test 'GET /projects/:id/dashboard_blocks.json of an invisible project is not found' do
      project = Project.generate! is_public: false

      get "/projects/#{project.identifier}/dashboard_blocks.json", headers: credentials('jsmith')

      assert_response :not_found
    end

    test 'GET /dashboard_blocks.json without credentials requires a login' do
      with_settings login_required: '1' do
        get '/dashboard_blocks.json'
      end

      assert_response :unauthorized
    end

    # Even where Redmine requires no login: blocks may compute a lot
    test 'GET /dashboard_blocks.json without credentials requires a login without login_required' do
      with_settings login_required: '0' do
        get '/dashboard_blocks.json'
      end

      assert_response :unauthorized
    end

    test 'GET /dashboard_blocks/:id.json without credentials requires a login without login_required' do
      with_settings login_required: '0' do
        get '/dashboard_blocks/news.json'
      end

      assert_response :unauthorized
    end

    # The server would read any URL of a request for everyone else
    test 'GET /dashboard_blocks/feed.json is forbidden for users who may not save dashboards' do
      get '/dashboard_blocks/feed.json', params: { settings: { url: 'https://example.org/feed' } },
                                         headers: credentials('jsmith')

      assert_response :forbidden
    end

    test 'GET /dashboard_blocks/feed.json is allowed for users who may save dashboards' do
      Role.find(1).add_permission! :save_dashboards

      get '/dashboard_blocks/feed.json', params: { settings: { url: 'ftp://127.0.0.1/feed.xml' } },
                                         headers: credentials('jsmith')

      assert_response :success
    end

    private

    def block_ids
      response.parsed_body['dashboard_blocks'].pluck 'id'
    end

    def listed_block(id)
      response.parsed_body['dashboard_blocks'].detect { |block| block['id'] == id }
    end

    def json_block
      response.parsed_body['dashboard_block']
    end
  end
end
