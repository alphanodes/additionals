# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class GlobalHelperTest < Additionals::HelperTest
  include Additionals::Helpers
  include RedminePluginKit::Helpers::GlobalHelper
  include AdditionalsFontawesomeHelper
  include AdditionalsMenuHelper
  include CustomFieldsHelper
  include AvatarsHelper
  include Redmine::I18n
  include ERB::Util

  def test_user_with_avatar
    html = user_with_avatar users(:users_001)

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

  def test_link_to_url
    assert_equal 'redmine.org/test', Nokogiri::HTML.parse(link_to_url('http://redmine.org/test')).xpath('//a').first.text
    assert_equal 'redmine.org/test', Nokogiri::HTML.parse(link_to_url('https://redmine.org/test')).xpath('//a').first.text
  end

  # select2 does not support allowClear on multiple selects: it renders a
  # "Remove all items" clear button as a stray empty choice. Disable it there.
  def test_autocomplete_select_entries_disables_allow_clear_for_multiple
    html = autocomplete_select_entries 'test[user_ids][]', 'assignee_auto_completes', nil,
                                       multiple: true, allow_clear: true

    assert_include 'allowClear: false', html
  end

  def test_autocomplete_select_entries_keeps_allow_clear_for_single
    html = autocomplete_select_entries 'test[user_id]', 'assignee_auto_completes', nil,
                                       multiple: false, allow_clear: true

    assert_include 'allowClear: true', html
  end
end
