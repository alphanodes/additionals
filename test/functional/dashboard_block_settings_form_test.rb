# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Every setting the settings form of a block sends is declared in its
# settings, so a new setting cannot be added to the form only
class DashboardBlockSettingsFormTest < Additionals::ControllerTest
  tests WelcomeController

  BLOCKS = %w[text text_async news documents my_spent_time feed activity issuequery issuequery__1].freeze

  def setup
    prepare_tests
    Setting.default_language = 'en'
    @request.session[:user_id] = 1
    User.current = users :users_001
  end

  def test_settings_forms_send_declared_settings_only
    dashboard = Dashboard.create! name: 'Settings forms', dashboard_type: DashboardContentWelcome::TYPE_NAME,
                                  author: User.current, visibility: Dashboard::VISIBILITY_PUBLIC,
                                  layout: { 'left' => BLOCKS },
                                  layout_settings: { 'issuequery__1' => { query_id: queries(:queries_004).id.to_s } }

    get :index, params: { dashboard_id: dashboard.id }

    assert_equal({}, undeclared_settings(dashboard))
  end

  def test_settings_forms_render_all_blocks
    dashboard = Dashboard.create! name: 'Settings forms', dashboard_type: DashboardContentWelcome::TYPE_NAME,
                                  author: User.current, visibility: Dashboard::VISIBILITY_PUBLIC,
                                  layout: { 'left' => BLOCKS }

    get :index, params: { dashboard_id: dashboard.id }

    assert_equal BLOCKS, BLOCKS & form_settings.keys
  end

  private

  def form_settings
    css_select('[name^="settings["]').each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |field, settings|
      block, key = field['name'].match(/\Asettings\[(\w+)\]\[(\w+)\]/).captures
      settings[block] |= [key.to_sym]
    end
  end

  # Keys of each form that its block does not declare, all of them for a block
  # without declared settings
  def undeclared_settings(dashboard)
    form_settings.each_with_object({}) do |(block, keys), undeclared|
      missing = keys - dashboard.content.block_settings_definitions(block).to_h.keys
      undeclared[block] = missing if missing.any?
    end
  end
end
