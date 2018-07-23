$VERBOSE = nil

unless ENV['SKIP_COVERAGE']
  require 'simplecov'
  require 'simplecov-rcov'

  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter[SimpleCov::Formatter::HTMLFormatter,
                                                              SimpleCov::Formatter::RcovFormatter]

  SimpleCov.start :rails do
    add_filter 'init.rb'
    root File.expand_path(File.dirname(__FILE__) + '/..')
  end
end

require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

if defined?(RSpec)
  RSpec.configure do |config|
    config.mock_with :mocha
    config.example_status_persistence_file_path = Rails.root.join('tmp', 'additionals_rspec_examples.txt')
  end
end

module Additionals
  module TestHelper
    def with_additionals_settings(settings, &_block)
      Setting.plugin_additionals = ActionController::Parameters.new(Setting.plugin_additionals.merge(settings))
      yield
    ensure
      Setting.plugin_additionals = Setting.plugin_additionals
    end
  end

  class ControllerTest < Redmine::ControllerTest
  end

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

    def self.arrays_equal?(value1, value2)
      (value1 - value2) - (value2 - value1) == []
    end

    def self.create_fixtures(fixtures_directory, table_names, _class_names = {})
      ActiveRecord::FixtureSet.create_fixtures(fixtures_directory, table_names, _class_names = {})
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

include Additionals::TestHelper
