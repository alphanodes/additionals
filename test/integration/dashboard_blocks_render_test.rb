# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Every block of additionals renders, with the page and loaded after it
class DashboardBlocksRenderTest < Additionals::IntegrationTest
  # legacy_left and legacy_right show the hooks of core only, without them
  # they are left out
  def test_welcome_blocks_render
    assert_dashboard_blocks_render %w[welcome text text_async news documents my_spent_time feed activity issuequery],
                                   layout_settings: { 'text_async' => { text: 'Hello' },
                                                      'issuequery' => { query_id: '4' } }
  end

  def test_project_blocks_render
    assert_dashboard_blocks_render %w[projectinformation projectissues projecttimeentries projectmembers projectsubprojects
                                      news documents issuequery],
                                   project: projects(:projects_001),
                                   layout_settings: { 'issuequery' => { query_id: '4' } }
  end
end
