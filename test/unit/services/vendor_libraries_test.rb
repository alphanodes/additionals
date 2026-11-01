# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

module Additionals
  class VendorLibrariesTest < Additionals::TestCase
    REGISTRY = Additionals::VendorLibraries::REGISTRY_URL
    TARBALL_URL = "#{REGISTRY}/demo-lib/-/demo-lib-2.0.0.tgz".freeze
    FOREIGN_TARBALL = %r{not below #{Regexp.escape REGISTRY}/demo-lib/-/}

    def setup
      super
      @root = Dir.mktmpdir
      FileUtils.mkdir_p File.join(@root, 'config')
      FileUtils.mkdir_p File.join(@root, 'assets/javascripts/vendor')
      File.write File.join(@root, 'assets/javascripts/vendor/demo.min.js'), 'old'
      File.write File.join(@root, 'README.md'), "| Library | Version |\n| ------- | ------- |\n" \
                                                "| [Demo](https://example.com/demo) (patched) | 1.0.0 |\n"
      File.write File.join(@root, 'config/vendor_libraries.yml'), {
        'demo' => { 'package' => 'demo-lib', 'version' => '1.0.0', 'title' => 'Demo', 'guide' => 'docs/demo.md',
                    'files' => [{ 'source' => 'dist/demo.min.js', 'target' => 'assets/javascripts/vendor/demo.min.js',
                                  'sha256' => Digest::SHA256.hexdigest('old') }] }
      }.to_yaml
      @vendor = Additionals::VendorLibraries.new root: @root
    end

    def teardown
      FileUtils.remove_entry @root
      super
    end

    # Guards the shipped files: an update by hand has to go through the task
    def test_bundled_libraries_match_manifest_and_readme
      vendor = Additionals::VendorLibraries.new

      assert_empty vendor.modified_files.map(&:target)
      assert_empty vendor.readme_mismatches.map(&:name)
    end

    def test_update_replaces_files_and_records_version
      tarball = build_tarball 'package/dist/demo.min.js' => 'new', 'package/README.md' => 'readme'
      stub_package 'latest', tarball

      library = @vendor.update 'demo'

      assert_equal '2.0.0', library.version
      assert_equal 'new', File.read(File.join(@root, 'assets/javascripts/vendor/demo.min.js'))
      assert_equal [], Additionals::VendorLibraries.new(root: @root).modified_files
      assert_equal '2.0.0', Additionals::VendorLibraries.new(root: @root).find('demo').version
      assert_includes File.read(File.join(@root, 'README.md')), '| [Demo](https://example.com/demo) (patched) | 2.0.0 |'
    end

    def test_update_to_given_version
      stub_package '2.0.0', build_tarball('package/dist/demo.min.js' => 'new')

      assert_equal '2.0.0', @vendor.update('demo', version: '2.0.0').version
    end

    def test_update_rejects_tarball_with_wrong_integrity
      stub_package 'latest', build_tarball('package/dist/demo.min.js' => 'new'), integrity: 'sha512-wrong'

      assert_unchanged_after_error(/integrity mismatch/) { @vendor.update 'demo' }
    end

    def test_update_rejects_tarball_of_another_package_or_host
      ["#{REGISTRY}/other-lib/-/other-lib-2.0.0.tgz", 'https://example.com/demo-lib/-/demo-lib-2.0.0.tgz'].each do |url|
        stub_request(:get, "#{REGISTRY}/demo-lib/latest")
          .to_return body: { version: '2.0.0', dist: { tarball: url } }.to_json

        assert_unchanged_after_error(FOREIGN_TARBALL) { @vendor.update 'demo' }
      end
    end

    def test_update_fails_on_missing_empty_or_linked_file_in_tarball
      { 'missing' => build_tarball('package/dist/other.js' => 'new'),
        'empty' => build_tarball('package/dist/demo.min.js' => ''),
        'symlink' => build_tarball({ 'package/dist/other.js' => 'new' }, { 'package/dist/demo.min.js' => 'other.js' }) }
        .each do |kind, tarball|
          stub_package 'latest', tarball

          assert_unchanged_after_error(%r{dist/demo.min.js not found}, kind) { @vendor.update 'demo' }
        end
    end

    def test_update_follows_https_redirects_only
      stub_request(:get, "#{REGISTRY}/demo-lib/latest").to_return status: 301, headers: { 'Location' => '/demo-lib/2.0.0' }
      stub_package '2.0.0', build_tarball('package/dist/demo.min.js' => 'new')

      assert_equal '2.0.0', @vendor.update('demo').version

      stub_request(:get, "#{REGISTRY}/demo-lib/latest").to_return status: 301, headers: { 'Location' => 'http://registry.npmjs.org/demo-lib/2.0.0' }

      error = assert_raises(Additionals::VendorLibraries::Error) { @vendor.update 'demo' }

      assert_match(/only https is allowed/, error.message)
    end

    def test_update_fails_on_missing_readme_row
      File.write File.join(@root, 'README.md'), "no table\n"
      stub_package 'latest', build_tarball('package/dist/demo.min.js' => 'new')

      assert_unchanged_after_error(/no row for Demo/) { @vendor.update 'demo' }
    end

    def test_update_fails_on_registry_error
      stub_request(:get, "#{REGISTRY}/demo-lib/latest").to_return status: 404

      assert_unchanged_after_error(/404/) { @vendor.update 'demo' }
    end

    def test_update_of_unknown_library
      error = assert_raises(Additionals::VendorLibraries::Error) { @vendor.update 'unknown' }

      assert_match(/unknown library unknown, known: demo/, error.message)
    end

    def test_outdated_lists_libraries_with_newer_version
      stub_request(:get, "#{REGISTRY}/demo-lib/latest").to_return body: { version: '1.10.0' }.to_json

      assert_equal([%w[demo 1.10.0]], @vendor.outdated.map { |library, latest| [library.name, latest] })

      stub_request(:get, "#{REGISTRY}/demo-lib/latest").to_return body: { version: '1.0.0' }.to_json

      assert_empty @vendor.outdated

      stub_request(:get, "#{REGISTRY}/demo-lib/latest").to_return body: { version: 'foo_bar' }.to_json

      assert_raises(Additionals::VendorLibraries::Error) { @vendor.outdated }
    end

    def test_modified_files_and_readme_mismatches
      File.write File.join(@root, 'assets/javascripts/vendor/demo.min.js'), 'changed by hand'
      File.write File.join(@root, 'README.md'), "| [Demo](https://example.com/demo) | 0.9.0 |\n"

      assert_equal ['assets/javascripts/vendor/demo.min.js'], @vendor.modified_files.map(&:target)
      assert_equal ['demo'], @vendor.readme_mismatches.map(&:name)
    end

    private

    def assert_unchanged_after_error(message, case_name = 'update', &)
      error = assert_raises(Additionals::VendorLibraries::Error, case_name, &)

      assert_match message, error.message, case_name
      assert_equal 'old', File.read(File.join(@root, 'assets/javascripts/vendor/demo.min.js'))
      assert_equal '1.0.0', Additionals::VendorLibraries.new(root: @root).find('demo').version
    end

    def stub_package(version, tarball, integrity: "sha512-#{Digest::SHA512.base64digest tarball}")
      stub_request(:get, "#{REGISTRY}/demo-lib/#{version}")
        .to_return body: { name: 'demo-lib', version: '2.0.0', dist: { tarball: TARBALL_URL, integrity: integrity } }.to_json
      stub_request(:get, TARBALL_URL).to_return body: tarball
    end

    def build_tarball(files, symlinks = {})
      tar = StringIO.new
      Gem::Package::TarWriter.new tar do |writer|
        symlinks.each { |name, target| writer.add_symlink name, target, 0o777 }
        files.each { |name, content| writer.add_file_simple(name, 0o644, content.bytesize) { |io| io.write content } }
      end
      gz = StringIO.new
      Zlib::GzipWriter.wrap(gz) { |writer| writer.write tar.string }
      gz.string
    end
  end
end
