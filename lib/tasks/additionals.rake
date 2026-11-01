# frozen_string_literal: true

namespace :redmine do
  namespace :additionals do
    desc <<-DESCRIPTION
    Reset recently used dashboards from user preferences.

    Example:
      bundle exec rake redmine:additionals:reset_recently_dashboards RAILS_ENV=production
    DESCRIPTION
    task reset_recently_dashboards: :environment do
      cnt = 0
      UserPreference.find_each do |pref|
        next if pref.others.blank? || pref.others[:recently_used_dashboards].blank?

        pref.others.delete :recently_used_dashboards
        pref.save!
        cnt += 1
      end

      puts "recently dashboard_ids have been removed from #{cnt} user preferences."
      exit 0
    end

    namespace :vendor do
      desc <<-DESCRIPTION
      List the bundled libraries with a newer version on npm.

      Only for maintainers of additionals: the libraries are shipped with the
      plugin, an installation does not need to run anything.

      Example:
        bundle exec rake redmine:additionals:vendor:outdated
      DESCRIPTION
      task outdated: :environment do
        vendor = Additionals::VendorLibraries.new
        outdated = vendor.outdated
        outdated.each { |library, latest| puts "#{library.name}: #{library.version} -> #{latest}" }
        puts 'All libraries are up to date.' if outdated.empty?
        vendor.modified_files.each { |file| puts "Modified by hand: #{file.target}" }
      rescue Additionals::VendorLibraries::Error => e
        abort e.message
      end

      desc <<-DESCRIPTION
      Update bundled libraries from npm, recording the version in
      config/vendor_libraries.yml and README.md.

      NAME is one or more names of config/vendor_libraries.yml, separated by
      commas. VERSION installs a given version instead of the latest one, only
      with a single NAME.

      Examples:
        bundle exec rake redmine:additionals:vendor:update NAME=mermaid
        bundle exec rake redmine:additionals:vendor:update NAME=chartjs,chartjs_annotation
        bundle exec rake redmine:additionals:vendor:update NAME=mermaid VERSION=12.2.0
      DESCRIPTION
      task update: :environment do
        names = ENV['NAME'].to_s.strip_split
        abort 'Set NAME, see redmine:additionals:vendor:outdated' if names.empty?
        abort 'VERSION works only with a single NAME' if names.many? && ENV['VERSION'].present?

        vendor = Additionals::VendorLibraries.new
        # All names are checked before the first library is updated
        previous_versions = names.index_with { |name| vendor.find(name).version }
        previous_versions.each do |name, previous|
          library = vendor.update name, version: ENV.fetch('VERSION', nil)
          if library.version == previous
            puts "#{library.name}: #{library.version} reinstalled"
          else
            puts "#{library.name}: #{previous} -> #{library.version}"
            puts "  Check the update with #{library.guide}" if library.guide
          end
        end
        puts 'Review the diff, test the pages using the libraries and add a CHANGELOG entry.'
      rescue Additionals::VendorLibraries::Error => e
        abort e.message
      end
    end
  end
end
