# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__
require File.expand_path '../../../db/migrate/005_create_dashboard_defaults.rb', __FILE__

# Covers the author resolution used by the CreateDashboardDefaults migration.
# It must return a usable owner for the default dashboards and raise a clear,
# actionable error instead of a NoMethodError when none is found (#186).
class CreateDashboardDefaultsTest < Additionals::TestCase
  def teardown
    ENV.delete 'DEFAULT_USER_ID'
  end

  def test_dashboard_author_returns_first_active_admin
    assert_equal User.admin.active.first, CreateDashboardDefaults.dashboard_author
  end

  def test_dashboard_author_prefers_default_user_id_env
    user = users :users_002
    ENV['DEFAULT_USER_ID'] = user.id.to_s

    assert_equal user, CreateDashboardDefaults.dashboard_author
  end

  def test_dashboard_author_raises_without_active_admin
    User.where(admin: true).update_all admin: false

    error = assert_raises(RuntimeError) { CreateDashboardDefaults.dashboard_author }

    assert_match(/DEFAULT_USER_ID/, error.message)
  end

  def test_dashboard_author_raises_for_invalid_default_user_id
    ENV['DEFAULT_USER_ID'] = '0'

    error = assert_raises(RuntimeError) { CreateDashboardDefaults.dashboard_author }

    assert_match(/DEFAULT_USER_ID/, error.message)
  end
end
