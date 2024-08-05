# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsRouterTest < Additionals::TestCase
  include Redmine::I18n

  def test_url_for
    router = AdditionalsRouter.new

    assert_equal 'http://localhost:3000/', router.url_for(:home)
  end

  def test_routing_url
    router = AdditionalsRouter.new

    assert_equal 'http://localhost:3000/projects/1', router.project_url(1)
  end

  def test_routing_path
    router = AdditionalsRouter.new

    assert_equal '/projects/1', router.project_path(1)
  end
end
