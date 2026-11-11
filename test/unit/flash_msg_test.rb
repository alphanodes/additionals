# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class FlashMsgTest < Additionals::TestCase
  include Redmine::I18n

  def setup
    prepare_tests
    set_language_if_valid 'en'
  end

  def test_mail_message_names_the_address
    message = ApplicationController.new.flash_msg :notice_email_sent, mail: 'kurt@example.com'

    assert_equal 'An email was sent to kurt@example.com', message
  end

  # Core renders flash messages as HTML, values come from user input
  def test_values_mail_addresses_and_field_info_are_escaped
    controller = ApplicationController.new
    category = IssueCategory.new name: '<b>Printing</b>'

    { value: controller.flash_msg(:notice_email_sent, value: '<b>Kurt</b>'),
      mail: controller.flash_msg(:notice_email_sent, mail: '<b>kurt@example.com</b>'),
      code: controller.flash_msg(:notice_email_sent, code: '<b>Kurt</b>'),
      field: controller.flash_msg(:update, obj: category, field: :name) }.each do |kind, message|
      assert_includes message, '&lt;b&gt;', kind
      assert_not_includes message, '<b>', kind
    end
  end

  def test_code_is_emphasized
    message = ApplicationController.new.flash_msg :notice_email_sent, code: 'kurt@example.com'

    assert_equal 'An email was sent to <em>kurt@example.com</em>', message
  end

  # Core renders flash messages as HTML
  def test_error_messages_are_escaped
    record = IssueCategory.new
    record.errors.add :base, '<b>Printing</b> is in use'

    %i[save_error delete_error].each do |msg|
      message = ApplicationController.new.flash_msg msg, obj: record

      assert_includes message, '&lt;b&gt;Printing&lt;/b&gt; is in use', msg
      assert_not_includes message, '<b>', msg
    end
  end
end
