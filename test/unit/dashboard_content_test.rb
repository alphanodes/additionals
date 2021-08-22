# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DashboardContentTest < Additionals::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :trackers, :projects_trackers,
           :enabled_modules,
           :enumerations,
           :dashboards, :dashboard_roles

  def setup
    prepare_tests
  end

  def test_types
    assert DashboardContent.types.include?(DashboardContentProject::TYPE_NAME)
    assert DashboardContent.types.include?(DashboardContentWelcome::TYPE_NAME)
  end
end
