require 'simplecov'
require 'simplecov-rcov'

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter[SimpleCov::Formatter::HTMLFormatter,
                                                            SimpleCov::Formatter::RcovFormatter]

SimpleCov.start :rails do
  add_filter 'init.rb'
  root File.expand_path(File.dirname(__FILE__) + '/..')
end

require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

# Additionals helper class for tests
module Additionals
  class TestCase
    include ActionDispatch::TestProcess
    def self.plugin_fixtures(plugin, *fixture_names)
      plugin_fixture_path = "#{Redmine::Plugin.find(plugin).directory}/test/fixtures"
      if fixture_names.first == :all
        fixture_names = Dir["#{plugin_fixture_path}/**/*.{yml}"]
        fixture_names.map! { |f| f[(plugin_fixture_path.size + 1)..-5] }
      else
        fixture_names = fixture_names.flatten.map(&:to_s)
      end

      ActiveRecord::Fixtures.create_fixtures(plugin_fixture_path, fixture_names)
    end

    def uploaded_test_file(name, mime)
      ActionController::TestUploadedFile.new(ActiveSupport::TestCase.fixture_path + "/files/#{name}", mime, true)
    end

    def self.arrays_equal?(a1, a2)
      (a1 - a2) - (a2 - a1) == []
    end

    def self.create_fixtures(fixtures_directory, table_names, _class_names = {})
      if ActiveRecord::VERSION::MAJOR >= 4
        ActiveRecord::FixtureSet.create_fixtures(fixtures_directory, table_names, _class_names = {})
      else
        ActiveRecord::Fixtures.create_fixtures(fixtures_directory, table_names, _class_names = {})
      end
    end

    def self.prepare
      Role.where(id: [1, 2]).each do |r|
        r.permissions << :view_issues
        r.save
      end

      Project.where(id: [1, 2]).each do |project|
        EnabledModule.create(project: project, name: 'issue_tracking')
      end
    end
  end
end
