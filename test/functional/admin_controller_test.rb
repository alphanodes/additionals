# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdminControllerTest < Additionals::ControllerTest
  def setup
    @request.session[:user_id] = 1
  end

  def test_info
    get :info

    assert_response :success
    assert_select 'table.list tr.system_info'
  end

  # Core checks for a library installed with redmine:mermaid:install, but
  # renders mermaid code blocks with the one bundled in additionals.
  def test_info_shows_mermaid_as_available
    skip 'Redmine core renders no mermaid code blocks' unless defined? Redmine::Mermaid

    get :info

    assert_select 'tr', text: /#{Regexp.escape I18n.t(:text_mermaid_available)}/ do
      assert_select 'td.tick span.icon-ok'
    end
  end
end
