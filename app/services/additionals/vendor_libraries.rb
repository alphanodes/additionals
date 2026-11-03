# frozen_string_literal: true

require 'digest/sha2'
require 'net/http'
require 'rubygems/package'
require 'zlib'

module Additionals
  # Updates the bundled third-party libraries from their npm packages.
  #
  # config/vendor_libraries.yml lists every library that is copied unchanged
  # from an npm package: package, version, the files taken from the tarball
  # and their SHA-256. The files are committed and shipped with the plugin,
  # nothing is downloaded on an installation. Libraries changed by hand
  # (colorschemes) are not listed and stay maintained by hand.
  #
  # Maintainer tool behind the redmine:additionals:vendor rake tasks.
  class VendorLibraries
    MANIFEST = 'config/vendor_libraries.yml'
    README = 'README.md'
    REGISTRY_URL = 'https://registry.npmjs.org'

    Library = Data.define :name, :package, :version, :title, :guide, :files
    LibraryFile = Data.define :source, :target, :sha256

    class Error < StandardError; end

    attr_reader :root

    def initialize(root: Redmine::Plugin.find(:additionals).directory)
      @root = root.to_s
    end

    def libraries
      @libraries ||= load_manifest
    end

    def find(name)
      libraries.find { |library| library.name == name.to_s } ||
        raise(Error, "unknown library #{name}, known: #{libraries.map(&:name).to_comma_list}")
    end

    # Libraries with a newer version on npm, as [library, latest_version] pairs
    def outdated
      libraries.filter_map do |library|
        latest = package_metadata(library.package)['version']
        [library, latest] if newer? latest, library.version
      end
    end

    # Bundled files whose content does not match the manifest
    def modified_files
      libraries.flat_map { |library| library.files.select { |file| modified? file } }
    end

    # Libraries whose version in the README differs from the manifest
    def readme_mismatches
      readme = File.read File.join(root, README)
      libraries.reject { |library| readme[readme_row(library), 2] == library.version }
    end

    # Replaces the files of a library with those of the given version (default:
    # latest) and records the version in the manifest and the README.
    # Returns the updated library.
    def update(name, version: nil)
      library = find name
      metadata = package_metadata library.package, version.presence || 'latest'
      contents = extract_files library, download_tarball(library, metadata)
      updated = library.with version: metadata['version'],
                             files: library.files.map { |f| f.with sha256: Digest::SHA256.hexdigest(contents[f.source]) }
      readme = updated_readme updated

      library.files.each { |f| write f.target, contents[f.source] }
      replace_library updated
      write README, readme
      updated
    end

    private

    def load_manifest
      YAML.safe_load_file(File.join(root, MANIFEST)).map do |name, attrs|
        Library.new name: name,
                    package: attrs['package'],
                    version: attrs['version'].to_s,
                    title: attrs['title'],
                    guide: attrs['guide'],
                    files: attrs['files'].map { |f| LibraryFile.new(**f.symbolize_keys) }
      end
    end

    def replace_library(updated)
      @libraries = libraries.map { |library| library.name == updated.name ? updated : library }
      write MANIFEST, manifest_yaml
    end

    # Atomic, so an interrupted update never leaves a partially written file
    def write(path, content)
      File.atomic_write(File.join(root, path)) { |file| file.write content }
    rescue SystemCallError => e
      raise Error, "cannot write #{path}: #{e.message}"
    end

    def newer?(version, current)
      Gem::Version.new(version) > Gem::Version.new(current)
    rescue ArgumentError => e
      raise Error, e.message
    end

    def manifest_yaml
      libraries.to_h do |library|
        attrs = { 'package' => library.package, 'version' => library.version, 'title' => library.title }
        attrs['guide'] = library.guide if library.guide
        attrs['files'] = library.files.map { |f| f.to_h.stringify_keys }
        [library.name, attrs]
      end.to_yaml
    end

    # Matches the row of a library in the table of libraries, the version is
    # the second group
    def readme_row(library)
      /^(\| \[#{Regexp.escape library.title}\]\([^)]*\)[^|]* \| )([^|]+?)( \|)$/
    end

    def updated_readme(library)
      content = File.read File.join(root, README)
      raise Error, "no row for #{library.title} in #{README}" unless content.match? readme_row(library)

      content.sub readme_row(library), "\\1#{library.version}\\3"
    end

    def modified?(file)
      path = File.join root, file.target
      !File.file?(path) || Digest::SHA256.file(path).hexdigest != file.sha256
    end

    def package_metadata(package, version = 'latest')
      JSON.parse fetch("#{REGISTRY_URL}/#{package.sub '/', '%2F'}/#{version}")
    rescue JSON::ParserError => e
      raise Error, "invalid metadata of #{package}: #{e.message}"
    end

    # npm publishes a SHA-512 of every tarball in dist.integrity
    def download_tarball(library, metadata)
      url = metadata.dig 'dist', 'tarball'
      prefix = "#{REGISTRY_URL}/#{library.package}/-/"
      raise Error, "tarball of #{library.package} is not below #{prefix}: #{url}" unless url.to_s.start_with? prefix

      tarball = fetch url
      expected = metadata.dig 'dist', 'integrity'
      actual = "sha512-#{Digest::SHA512.base64digest tarball}"
      raise Error, "integrity mismatch of #{url}: expected #{expected}, got #{actual}" unless actual == expected

      tarball
    end

    # Returns the content of each file of the library, keyed by source
    def extract_files(library, tarball)
      wanted = library.files.map { |f| "package/#{f.source}" }
      contents = {}
      Zlib::GzipReader.wrap StringIO.new(tarball) do |gz|
        Gem::Package::TarReader.new gz do |tar|
          tar.each { |entry| contents[entry.full_name.delete_prefix('package/')] = entry.read if wanted.include? entry.full_name }
        end
      end

      # A symlink or directory entry reads as an empty string
      missing = library.files.filter_map { |file| file.source if contents[file.source].blank? }
      raise Error, "#{missing.to_comma_list} not found in #{library.package}" if missing.any?

      contents
    rescue Zlib::Error, Gem::Package::TarInvalidError => e
      raise Error, "cannot read the tarball of #{library.package}: #{e.message}"
    end

    def fetch(url, redirects_left = 5)
      raise Error, "too many redirects for #{url}" if redirects_left.zero?

      uri = URI.parse url
      raise Error, "#{url}: only https is allowed" unless uri.scheme == 'https'

      response = Net::HTTP.start uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 120 do |http|
        http.get uri.request_uri
      end
      case response
      when Net::HTTPSuccess then response.body
      when Net::HTTPRedirection
        raise Error, "#{url}: redirect without location" if response['location'].blank?

        fetch URI.join(url, response['location']).to_s, redirects_left - 1
      else raise Error, "#{url}: #{response.code} #{response.message}"
      end
    rescue URI::Error, SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => e
      raise Error, "#{url}: #{e.message}"
    end
  end
end
