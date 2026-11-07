# frozen_string_literal: true

require File.expand_path '../../../../../test/application_system_test_case', __FILE__
require File.expand_path '../../global_system_test_helper', __FILE__
require 'base64'
require 'tempfile'

# Files live on the test runner, so a remote browser must receive their bytes
# through Selenium's upload endpoint rather than a shared filesystem.
class RemoteFileUploadsTest < ApplicationSystemTestCase
  extend Additionals::GlobalSystemTestHelper

  use_plugin_system_test_driver

  def test_text_and_uploads_share_the_same_session
    html = '<input id="subject"><input id="attachment" type="file" multiple>'
    visit "data:text/html;base64,#{Base64.strict_encode64 html}"
    text = 'Ticket for a customer from the dialog'
    fill_in 'subject', with: text

    assert_field 'subject', with: text

    Tempfile.create ['additionals-upload-', '.txt'] do |first|
      Tempfile.create ['additionals-upload-', '.txt'] do |second|
        first.write 'First upload: äöü'
        second.write 'Second upload'
        first.flush
        second.flush
        attach_file 'attachment', first.path

        assert_equal ['First upload: äöü'], uploaded_contents

        fill_in 'subject', with: 'log'

        assert_field 'subject', with: 'log'

        attach_file 'attachment', [first.path, second.path]

        assert_equal ['First upload: äöü', 'Second upload'], uploaded_contents

        fill_in 'subject', with: text

        assert_field 'subject', with: text
      end
    end
  end

  private

  def uploaded_contents
    page.evaluate_async_script <<~JS
      const done = arguments[arguments.length - 1];
      Promise.all(Array.from(document.getElementById('attachment').files, file => file.text())).then(done);
    JS
  end
end
