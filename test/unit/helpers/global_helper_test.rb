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

  def test_autocomplete_select_entries_keeps_blank_option_for_single
    html = autocomplete_select_entries 'foo', 'assignee_auto_completes', nil,
                                       multiple: false, include_blank: true

    assert_match(/<option value=""/, html)
  end

  def test_autocomplete_select_entries_omits_blank_option_for_multiple
    html = autocomplete_select_entries 'foo', 'assignee_auto_completes', nil,
                                       multiple: true, include_blank: true

    assert_no_match(/<option value=""/, html)
    assert_match(/<input[^>]*type="hidden"[^>]*name="foo\[\]"/, html)
  end

  def test_autocomplete_select_entries_hidden_field_does_not_double_bracket_array_name
    html = autocomplete_select_entries 'foo[]', 'assignee_auto_completes', nil,
                                       multiple: true, include_blank: true

    assert_match(/<input[^>]*type="hidden"[^>]*name="foo\[\]"/, html)
    assert_no_match(/name="foo\[\]\[\]"/, html)
  end
end
