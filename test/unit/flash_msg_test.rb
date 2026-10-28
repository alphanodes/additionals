# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class FlashMsgTest < Additionals::TestCase
  include Redmine::I18n

  def setup
    prepare_tests
    set_language_if_valid 'en'
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
