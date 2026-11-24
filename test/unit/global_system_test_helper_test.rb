# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__
require 'capybara/rails'
require 'selenium-webdriver'
require File.expand_path '../../global_system_test_helper', __FILE__

class GlobalSystemTestHelperTest < Additionals::TestCase
  include Capybara::DSL
  include Additionals::GlobalSystemTestHelper::SessionHelper

  def setup
    super
    @previous_driver = Capybara.current_driver
    @previous_session = Capybara.session_name
    Capybara.session_name = :additionals_upload_contract
    Capybara.register_driver :additionals_upload_contract do |app|
      Capybara::Selenium::Driver.new app, browser: :remote, url: 'http://selenium.example.test',
                                          options: Selenium::WebDriver::Chrome::Options.new
    end
    Capybara.current_driver = :additionals_upload_contract
    stub_request(:post, 'http://selenium.example.test/session').to_return_json(
      body: { value: { sessionId: 'upload-contract', capabilities: { browserName: 'chrome', browserVersion: '130' } } }
    )
    stub_request(:delete, 'http://selenium.example.test/session/upload-contract').to_return_json body: { value: nil }
    stub_request(:post, 'http://selenium.example.test/session/upload-contract/execute/sync').to_return_json body: { value: nil }
    @typing = stub_request(:post, 'http://selenium.example.test/session/upload-contract/element/field/value')
              .to_return_json body: { value: nil }
  end

  def teardown
    Capybara.current_driver = :additionals_upload_contract
    page.driver.quit
    Capybara.current_driver = @previous_driver
    Capybara.session_name = @previous_session
    super
  end

  def test_registers_the_configuration_for_every_system_test
    host = Class.new ActiveSupport::TestCase
    host.extend Additionals::GlobalSystemTestHelper

    assert_includes host._setup_callbacks.map(&:filter), :configure_remote_file_uploads
  end

  def test_text_that_names_a_directory_is_not_uploaded
    configure_remote_file_uploads
    field.send :set_text, 'log'
    field.send :set_text, 'Ticket for a customer from the dialog'

    assert_requested @typing, times: 3
    assert_not_requested :post, 'http://selenium.example.test/session/upload-contract/se/file'
  end

  def test_uploads_real_files_and_restores_text_typing
    configure_remote_file_uploads
    paths = %w[testfile.txt testfile.md].map { |name| Rails.root.join('test/fixtures/files', name).to_s }
    uploads = []
    stub_request(:post, 'http://selenium.example.test/session/upload-contract/se/file').to_return do |request|
      Zip::InputStream.open StringIO.new(Base64.strict_decode64(JSON.parse(request.body).fetch('file'))) do |zip|
        entry = zip.get_next_entry
        uploads << [entry.name, zip.read]
      end
      { body: { value: "/remote/#{uploads.last.first}" }.to_json, headers: { 'Content-Type' => 'application/json' } }
    end

    field.send :set_file, paths.first
    field.send :set_text, 'log'
    field.send :set_file, paths
    field.send :set_text, 'log'

    assert_equal [paths.first, *paths].map { |path| [File.basename(path), File.binread(path)] }, uploads
    assert_nil page.driver.browser.send(:bridge).file_detector
    assert_requested @typing.with { |request| JSON.parse(request.body)['text'] == 'log' }, times: 2
    assert_requested(@typing.with { |request| JSON.parse(request.body)['text'] == '/remote/testfile.txt' })
    assert_requested(@typing.with { |request| JSON.parse(request.body)['text'] == "/remote/testfile.txt\n/remote/testfile.md" })
  end

  def test_local_drivers_do_not_start_a_browser
    Capybara.current_driver = :rack_test
    configure_remote_file_uploads

    assert_not_requested :post, 'http://selenium.example.test/session'
  end

  def test_failed_upload_restores_text_typing
    configure_remote_file_uploads
    stub_request(:post, 'http://selenium.example.test/session/upload-contract/se/file').to_return_json(
      status: 500, body: { value: { error: 'unknown error', message: 'Upload failed', stacktrace: '' } }
    )

    assert_raises Selenium::WebDriver::Error::UnknownError do
      field.send :set_file, Rails.root.join('test/fixtures/files/testfile.txt').to_s
    end

    field.send :set_text, 'log'

    assert_nil page.driver.browser.send(:bridge).file_detector
    assert_requested(@typing.with { |request| JSON.parse(request.body)['text'] == 'log' })
  end

  # Chrome 158 rejects Capybara's storage reset for the origin "*", so the
  # storage of the application is cleared instead. Locally core sets the app
  # host without a port, and the origin has to be the one the browser visited.
  def test_storage_reset_clears_the_origin_the_browser_visited
    Additionals::GlobalSystemTestHelper::ChromeStorageReset.apply!
    origins = []
    stub_request(:post, 'http://selenium.example.test/session/upload-contract/goog/cdp/execute').to_return do |request|
      params = JSON.parse(request.body)['params']
      if params['origin'] == '*'
        { status: 400, body: { value: { error: 'invalid argument', message: 'Invalid origin', stacktrace: '' } }.to_json,
          headers: { 'Content-Type' => 'application/json' } }
      else
        origins << params['origin'] if params.key? 'origin'
        { body: { value: {} }.to_json, headers: { 'Content-Type' => 'application/json' } }
      end
    end
    server = page.server
    # Capybara extends the driver for Chrome only once the browser has started
    page.driver.browser

    with_capybara_app_host "http://#{server.host}:" do
      page.driver.send :execute_cdp, 'Storage.clearDataForOrigin', origin: '*', storageTypes: 'cookies,local_storage'
    end

    assert_equal ["http://#{server.host}:#{server.port}"], origins
  end

  private

  def with_capybara_app_host(host)
    previous = [Capybara.app_host, Capybara.always_include_port]
    # Rails switches this on for every system test (ActionDispatch::SystemTesting::Server)
    Capybara.always_include_port = true
    Capybara.app_host = host
    yield
  ensure
    Capybara.app_host, Capybara.always_include_port = previous
  end

  def field
    driver = page.driver
    native = Selenium::WebDriver::Element.new driver.browser.send(:bridge), 'field'
    Capybara::Selenium::Node.new driver, native
  end
end
