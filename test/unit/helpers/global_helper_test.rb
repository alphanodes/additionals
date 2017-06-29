require File.expand_path('../../../test_helper', __FILE__)

class GlobalHelperTest < ActionView::TestCase
  include ApplicationHelper
  include Additionals::Helpers
  include CustomFieldsHelper
  include Redmine::I18n
  include ERB::Util

  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :custom_fields,
           :attachments,
           :versions

  def setup
    super
    set_language_if_valid('en')
    User.current = nil
  end

  def test_system_info
    text = system_info

    assert_not_equal '', text
    assert_not_equal 'unknown', text
  end

  def test_windows_platform
    assert_nil windows_platform?
  end

  def test_user_with_avatar
    html = user_with_avatar(User.find(1))

    assert_include 'Redmine Admin', html
  end

  def test_fa_icon
    html = fa_icon('fa-car', class: 'test')
    assert_include 'class="fa fa-car test"', html

    html = fa_icon('fa-car', pre_text: 'Testing')
    assert_include 'Testing <span', html

    html = fa_icon('fa-car', post_text: 'Testing')
    assert_include '</span> Testing', html
  end
end
