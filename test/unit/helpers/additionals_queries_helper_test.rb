# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class AdditionalsQueriesHelperTest < Additionals::HelperTest
  include AdditionalsQueriesHelper
  # flash_msg lives in the ApplicationController patch - set_flash_from_bulk_save
  # is a controller method that happens to sit in a helper module.
  include Additionals::Patches::ApplicationControllerPatch::InstanceMethods

  def test_bulk_save_flash_names_the_reason_for_every_failure
    unsaved = invalid_issues

    set_flash_from_bulk_save unsaved, unsaved, name_plural: 'issues'

    assert_includes flash[:error], '2 of 2 selected issues could not be saved'
    assert_includes flash[:error], "##{unsaved.first.id}"
    assert_includes flash[:error], 'Subject cannot be blank'
  end

  def test_bulk_save_flash_lists_the_reasons_as_markup
    unsaved = invalid_issues

    set_flash_from_bulk_save unsaved, unsaved, name_plural: 'issues'

    assert_includes flash[:error], '<ul><li>'
    assert_predicate flash[:error], :html_safe?
  end

  def test_bulk_save_flash_reports_success_when_nothing_failed
    set_flash_from_bulk_save [issues(:issues_001)], [], name_plural: 'issues'

    assert_nil flash[:error]
    assert_not_nil flash[:notice]
  end

  def test_bulk_save_flash_stays_silent_without_entries
    set_flash_from_bulk_save [], [], name_plural: 'issues'

    assert_nil flash[:error]
    assert_nil flash[:notice]
  end

  private

  # Validation has to run for errors.full_messages to hold anything.
  def invalid_issues
    [issues(:issues_001), issues(:issues_002)].each do |issue|
      issue.subject = ''
      issue.valid?
    end
  end
end
