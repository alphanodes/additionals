# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class DashboardServiceTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
  end

  def test_dashboards_are_those_the_user_can_see
    assert_equal Dashboard.visible(users(:users_002)).sorted.ids,
                 Additionals::DashboardService.new(user: users(:users_002)).dashboards.ids
  end

  def test_dashboards_of_a_type
    assert_equal [DashboardContentWelcome::TYPE_NAME],
                 service.dashboards(dashboard_type: DashboardContentWelcome::TYPE_NAME).pluck(:dashboard_type).uniq
  end

  def test_dashboards_of_a_project_include_those_for_all_projects
    assert_includes service.dashboards(project: projects(:projects_002)), dashboards(:system_default_project)
  end

  def test_dashboards_of_a_project_leave_out_other_projects
    other = Dashboard.project_only.where.not(project_id: [nil, 2]).ids

    assert_not service.dashboards(project: projects(:projects_002)).ids.intersect?(other)
  end

  def test_dashboards_of_a_project_leave_out_welcome_dashboards
    assert_not_includes service.dashboards(project: projects(:projects_002)), dashboards(:system_default_welcome)
  end

  private

  def service
    Additionals::DashboardService.new
  end
end
