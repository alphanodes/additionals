# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2016 AlphaNodes GmbH

require File.expand_path('../../test_helper', __FILE__)

# Redmine Tweaks unit tests
class TweaksTest < ActiveSupport::TestCase
  fixtures :users, :members, :projects, :roles, :member_roles,
           :journals, :journal_details,
           :groups_users,
           :enabled_modules

  def setup
    @admin = User.find(1)
    @jsmith = User.find(2)
    @dlopper = User.find(3)
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
