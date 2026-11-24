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
  # (colorschemes) are not listed and stay maintained by hand. A library with
  # a constraint (a RubyGems requirement such as "~> 9.1") is only updated to
  # versions within it, its reason says why. A comment pointing to a source
  # map which the library does not ship is removed, else Propshaft warns
  # about the missing map whenever it compiles the file.
  #
  # Maintainer tool behind the redmine:additionals:vendor rake tasks.
  class VendorLibraries
    MANIFEST = 'config/vendor_libraries.yml'
    README = 'README.md'
    REGISTRY_URL = 'https://registry.npmjs.org'
    # The source map comment at the end of a file, as Propshaft looks for it
    SOURCE_MAP = %r{\n?(?://|/\*)# sourceMappingURL=(\S+?\.map)(?:\s*\*/)?\s*\z}

    Library = Data.define :name, :package, :version, :title, :guide, :constraint, :reason, :files
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

    # Libraries with a newer version on npm, as [library, latest_version] pairs.
    # For a library with a constraint, latest is the newest version within it.
    def outdated
      libraries.filter_map do |library|
        latest = library.constraint ? newest_allowed_version(library) : package_metadata(library.package)['version']
        [library, latest] if newer? latest, library.version
      end
    end

    def constrained
      libraries.select(&:constraint)
    end

    # Bundled files whose content does not match the manifest
    def modified_files
      libraries.flat_map { |library| library.files.select { |file| modified? file } }
    end

    # Bundled files pointing to a source map which is not bundled
    def missing_source_maps
      libraries.flat_map do |library|
        library.files.select do |file|
          path = File.join root, file.target
          File.file?(path) && source_map_missing?(library, file, File.binread(path))
        end
      end
    end

    # Libraries whose version in the README differs from the manifest
    def readme_mismatches
      readme = File.read File.join(root, README)
      libraries.reject { |library| readme[readme_row(library), 2] == library.version }
    end

    # Replaces the files of a library with those of the given version (default:
    # latest, within the constraint of the library) and records the version in
    # the manifest and the README. Returns the updated library.
    def update(name, version: nil)
      library = find name
      metadata = package_metadata library.package, target_version(library, version.presence)
      contents = without_missing_source_maps library, extract_files(library, download_tarball(library, metadata))
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
                    constraint: requirement(name, attrs['constraint']),
                    reason: attrs['reason'],
                    files: attrs['files'].map { |f| LibraryFile.new(**f.symbolize_keys) }
      end
    end

    def without_missing_source_maps(library, contents)
      library.files.to_h do |file|
        content = contents[file.source]
        [file.source, source_map_missing?(library, file, content) ? content.sub(SOURCE_MAP, "\n") : content]
      end
    end

    def source_map_missing?(library, file, content)
      map = content[SOURCE_MAP, 1]
      return false unless map

      target = File.join File.dirname(file.target), map
      library.files.none? { |shipped| shipped.target == target }
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

    def requirement(name, constraint)
      return if constraint.blank?

      Gem::Requirement.new(*constraint.to_s.strip_split)
    rescue Gem::Requirement::BadRequirementError => e
      raise Error, "invalid constraint of #{name}: #{e.message}"
    end

    def target_version(library, version)
      return version || 'latest' unless library.constraint
      return newest_allowed_version library unless version
      return version if library.constraint.satisfied_by? Gem::Version.new(version)

      raise Error, "#{library.name} #{version} is outside its constraint #{library.constraint}: #{library.reason}"
    rescue ArgumentError => e
      raise Error, e.message
    end

    # Newest stable version on npm within the constraint of the library
    def newest_allowed_version(library)
      versions = package_document(library.package).fetch('versions', {}).keys
      allowed = versions.filter_map do |version|
        next unless Gem::Version.correct? version

        parsed = Gem::Version.new version
        parsed if !parsed.prerelease? && library.constraint.satisfied_by?(parsed)
      end
      raise Error, "no version of #{library.package} within #{library.constraint}" if allowed.empty?

      allowed.max.to_s
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
        attrs['constraint'] = library.constraint.to_s if library.constraint
        attrs['reason'] = library.reason if library.reason
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

    # All versions of a package, in the abbreviated form npm offers for installers
    def package_document(package)
      JSON.parse fetch("#{REGISTRY_URL}/#{package.sub '/', '%2F'}", accept: 'application/vnd.npm.install-v1+json')
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

    def fetch(url, redirects_left = 5, accept: nil)
      raise Error, "too many redirects for #{url}" if redirects_left.zero?

      uri = URI.parse url
      raise Error, "#{url}: only https is allowed" unless uri.scheme == 'https'

      response = Net::HTTP.start uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 120 do |http|
        http.get uri.request_uri, accept ? { 'Accept' => accept } : {}
      end
      case response
      when Net::HTTPSuccess then response.body
      when Net::HTTPRedirection
        raise Error, "#{url}: redirect without location" if response['location'].blank?

        fetch URI.join(url, response['location']).to_s, redirects_left - 1, accept:
      else raise Error, "#{url}: #{response.code} #{response.message}"
      end
    rescue URI::Error, SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => e
      raise Error, "#{url}: #{e.message}"
    end
  end
end
