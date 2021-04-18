# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class GlobalHelperTest < ActionView::TestCase
  include Additionals::Helpers
  include AdditionalsFontawesomeHelper
  include AdditionalsMenuHelper
  include CustomFieldsHelper
  include AvatarsHelper
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
    set_language_if_valid 'en'
    User.current = nil
  end

  def test_user_with_avatar
    html = user_with_avatar(users(:users_001))

    assert_include 'Redmine Admin', html
  end

  def test_font_awesome_icon
    html = font_awesome_icon 'fas_cloud-upload-alt', class: 'test'
    assert_include 'class="fas fa-cloud-upload-alt test"', html

    html = font_awesome_icon 'fab_xing', class: 'test'
    assert_include 'class="fab fa-xing test"', html

    html = font_awesome_icon 'fas_cloud-upload-alt', pre_text: 'Testing'
    assert_include 'Testing <span', html

    html = font_awesome_icon 'fas_cloud-upload-alt', post_text: 'Testing'
    assert_include '</span> Testing', html
  end

  def test_parse_issue_url
    stubs(:request).returns(stub('original_url' => 'http://redmine.local/issues/1#note-2'))

    assert_equal({ issue_id: nil, comment_id: nil },
                 parse_issue_url(0, nil))
    assert_equal({ issue_id: nil, comment_id: nil },
                 parse_issue_url('', nil))
    assert_equal({ issue_id: nil, comment_id: nil },
                 parse_issue_url('http://localhost/issue/23', nil))
    assert_equal({ issue_id: '23', comment_id: nil },
                 parse_issue_url('http://redmine.local/issues/23', nil))
    assert_equal({ issue_id: '23', comment_id: 2 },
                 parse_issue_url('http://redmine.local/issues/23#note-2', nil))
    assert_equal({ issue_id: '23', comment_id: 2 },
                 parse_issue_url('http://redmine.local/issues/issues/23/edit#note-2', nil))
  end

  def test_render_issue_macro_link
    issue = Issue.generate!
    issue.init_journal User.first, 'Adding notes'
    issue.save

    stubs(:request).returns(stub('original_url' => 'http://redmine.local/issues/1#note-2'))

    assert_match %r{/issues/#{issue.id}}, render_issue_macro_link(issue, 'Sample subject')
    assert_no_match(/Adding notes/, render_issue_macro_link(issue, 'Sample subject'))
    assert_match(/Adding notes/, render_issue_macro_link(issue, 'Sample subject', 1))
    assert_match %r{N/A}, render_issue_macro_link(issue, 'Sample subject', 100)
  end
end
