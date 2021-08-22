# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class RoleTest < Additionals::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :trackers, :projects_trackers,
           :enabled_modules,
           :roles

  def setup
    prepare_tests
  end

  def test_with_permission
    role = Role.new name: 'role without hide'
    assert_save role

    role.reload
    assert_not role.hide

    role = Role.new name: 'role with hide', hide: true
    assert_save role

    role.reload
    assert role.hide
  end

  def test_edit
    role = roles :roles_001
    role.hide = true
    assert_save role

    role.reload
    assert role.hide
  end
end
