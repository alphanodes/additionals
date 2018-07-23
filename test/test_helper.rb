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

    def prepare_tests
      Role.where(id: [1, 2]).each do |r|
        r.permissions << :view_issues
        r.save
      end

      Project.where(id: [1, 2]).each do |project|
        EnabledModule.create(project: project, name: 'issue_tracking')
      end
    end
  end

  class ControllerTest < Redmine::ControllerTest
    include Additionals::TestHelper
  end

  class TestCase < ActiveSupport::TestCase
    include Additionals::TestHelper
  end
end
