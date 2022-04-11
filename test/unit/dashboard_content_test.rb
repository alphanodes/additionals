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
    assert_includes DashboardContent.types, DashboardContentProject::TYPE_NAME
    assert_includes DashboardContent.types, DashboardContentWelcome::TYPE_NAME
  end
end
