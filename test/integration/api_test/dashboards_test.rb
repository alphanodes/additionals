# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

module ApiTest
  # Dashboards for programs: the list with filters and the layout of one
  class DashboardsTest < Additionals::ApiTest
    test 'GET /dashboards/:id.json gives a reader no stored block settings' do
      get "/dashboards/#{welcome_dashboard.id}.json", headers: credentials('jsmith')

      assert_not_includes response.body, 'Some example text in left text block'
    end

    test 'GET /dashboards/:id.json lists the blocks of each group' do
      get "/dashboards/#{welcome_dashboard.id}.json", headers: credentials('jsmith')

      assert_equal %w[text text_async legacy_left], layout_group('left').pluck('id')
    end

    test 'GET /dashboards/:id.json names the label of the block type' do
      get "/dashboards/#{welcome_dashboard.id}.json", headers: credentials('jsmith')

      assert_equal 'Text', layout_block('left', 'text')['label']
    end

    test 'GET /dashboards/:id.json leaves out the settings of blocks for a reader' do
      get "/dashboards/#{welcome_dashboard.id}.json", headers: credentials('jsmith')

      assert_not layout_block('left', 'text').key?('settings')
    end

    test 'GET /dashboards/:id.json gives an editor the typed settings of blocks' do
      get "/dashboards/#{welcome_dashboard.id}.json", headers: credentials('admin')

      assert_equal 'Some example text in left text block', layout_block('left', 'text')['settings']['text']
    end

    test 'GET /dashboards/:id.json gives the author who may save dashboards the settings of blocks' do
      Role.find(1).add_permission! :save_dashboards
      dashboard = Dashboard.create! name: 'Of jsmith', dashboard_type: DashboardContentWelcome::TYPE_NAME,
                                    author: users(:users_002), visibility: Dashboard::VISIBILITY_PUBLIC,
                                    layout: { 'left' => %w[text] }, layout_settings: { 'text' => { text: 'Secret' } }

      get "/dashboards/#{dashboard.id}.json", headers: credentials('jsmith')

      assert_equal 'Secret', layout_block('left', 'text')['settings']['text']
    end

    test 'GET /dashboards/:id.json gives an anonymous user no stored block settings' do
      get "/dashboards/#{welcome_dashboard.id}.json"

      assert_not_includes response.body, 'Some example text in left text block'
    end

    # assign_layout keeps such a block, an editor sees it to place the others around it
    test 'GET /dashboards/:id.json marks a block an editor cannot use here' do
      Role.find(1).add_permission! :save_dashboards
      dashboard = Dashboard.create! name: 'Of jsmith', dashboard_type: DashboardContentWelcome::TYPE_NAME,
                                    author: users(:users_002), visibility: Dashboard::VISIBILITY_PUBLIC,
                                    layout: { 'left' => %w[news text] }
      Role.find_each { |role| role.remove_permission! :view_news }

      get "/dashboards/#{dashboard.id}.json", headers: credentials('jsmith')

      assert_equal [false, true], layout_group('left').pluck('available')
    end

    test 'GET /dashboards/:id.json tells a reader the dashboard is not editable' do
      get "/dashboards/#{welcome_dashboard.id}.json", headers: credentials('jsmith')

      assert_equal [false, false], json_dashboard.values_at('editable', 'layout_editable')
    end

    test 'GET /dashboards/:id.xml lists the blocks of each group' do
      get "/dashboards/#{welcome_dashboard.id}.xml", headers: credentials('jsmith')

      assert_select 'dashboard>layout>group>blocks>block>id', text: 'text_async'
    end

    test 'GET /dashboards.json filters by dashboard type' do
      get '/dashboards.json', params: { dashboard_type: DashboardContentWelcome::TYPE_NAME }, headers: credentials('admin')

      assert_equal [DashboardContentWelcome::TYPE_NAME], json_dashboards.pluck('dashboard_type').uniq
    end

    test 'GET /dashboards.json with a project lists the dashboards offered in the project' do
      get '/dashboards.json', params: { project_id: 'onlinestore' }, headers: credentials('admin')

      assert_equal Dashboard.visible(users(:users_001)).project_only.where(project_id: [2, nil]).sorted.ids,
                   json_dashboards.pluck('id')
    end

    test 'GET /dashboards.json counts the filtered dashboards' do
      get '/dashboards.json', params: { dashboard_type: DashboardContentWelcome::TYPE_NAME }, headers: credentials('admin')

      assert_equal json_dashboards.size, response.parsed_body['total_count']
    end

    private

    def welcome_dashboard
      dashboards :system_default_welcome
    end

    def json_dashboard
      response.parsed_body['dashboard']
    end

    def json_dashboards
      response.parsed_body['dashboards']
    end

    def layout_group(name)
      json_dashboard['layout'].detect { |group| group['name'] == name }['blocks']
    end

    def layout_block(group, id)
      layout_group(group).detect { |block| block['id'] == id }
    end
  end
end
