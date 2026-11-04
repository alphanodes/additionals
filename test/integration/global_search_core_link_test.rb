# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# The dialog of the global search counts its hits and links to the core search page for all
# of them. In the scope "project" both have to search the same project, or the page behind
# the link shows other hits than the number next to it.
class GlobalSearchCoreLinkTest < Additionals::IntegrationTest
  def setup
    prepare_tests
    log_user 'admin', 'admin'
  end

  # ecookbook has subprojects: neither they nor other projects belong to the hits
  test 'dialog and core page search exactly the project' do
    with_plugin_settings 'additionals', global_search: 1 do
      dialog = dialog_data 'ecookbook'
      page_ids, page_count = core_page_results dialog, 'issue'

      assert_includes page_ids, issues(:issues_007).id
      assert_not_includes page_ids, issues(:issues_004).id
      assert_not_includes page_ids, issues(:issues_005).id
      assert_equal dialog_count(dialog, 'issue'), page_count
    end
  end

  private

  # The data attributes the dialog works with, as the project page renders them
  def dialog_data(project_identifier)
    get "/projects/#{project_identifier}"

    assert_response :success
    overlay = css_select('#global-search-overlay').first

    assert overlay, 'the dialog of the global search is rendered'
    overlay.attributes.transform_values(&:value)
  end

  # What the dialog counts in the scope "project", summed over the tabs it offers there
  def dialog_count(dialog, query)
    get dialog['data-global-search-url-value'],
        params: { q: query, project_id: dialog['data-global-search-project-id-value'] }

    assert_response :success
    counts = response.parsed_body['counts']
    types = JSON.parse(dialog['data-search-types-project']).pluck('id')
    types.sum { |type| counts[type].to_i }
  end

  # Follows the link of the dialog to the core search page: the issues of the first page of
  # hits and the number of all hits
  def core_page_results(dialog, query)
    get dialog['data-core-search-project-url'], params: { q: query, attachments: '1' }

    assert_response :success
    ids = css_select('#search-results dt a').filter_map { |link| link['href'][%r{\A/issues/(\d+)\z}, 1]&.to_i }
    [ids, css_select('#content h3').text[/\((\d+)\)/, 1].to_i]
  end
end
