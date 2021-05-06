# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start :rails do
    add_filter 'init.rb'
    root File.expand_path "#{File.dirname __FILE__}/.."
  end
end

require File.expand_path "#{File.dirname __FILE__}/../../../test/test_helper"
require File.expand_path "#{File.dirname __FILE__}/global_test_helper"
require File.expand_path "#{File.dirname __FILE__}/crud_controller_base"

module Additionals
  module TestHelper
    include Additionals::GlobalTestHelper

    def prepare_tests
      Role.where(id: [1, 2]).each do |r|
        r.permissions << :save_dashboards
        r.save
      end

      Role.where(id: [1]).each do |r|
        r.permissions << :share_dashboards
        r.permissions << :set_system_dashboards
        r.save
      end

      Project.where(id: [1, 2]).each do |project|
        EnabledModule.create project: project, name: 'issue_tracking'
      end
    end
  end

  module PluginFixturesLoader
    def fixtures(*table_names)
      dir = "#{File.dirname __FILE__}/fixtures/"
      table_names.each do |x|
        ActiveRecord::FixtureSet.create_fixtures dir, x if File.exist? "#{dir}/#{x}.yml"
      end
      super table_names
    end
  end

  class ControllerTest < Redmine::ControllerTest
    include Additionals::TestHelper
    extend PluginFixturesLoader
  end

  class TestCase < ActiveSupport::TestCase
    include Additionals::TestHelper
    extend PluginFixturesLoader
  end

  class IntegrationTest < Redmine::IntegrationTest
    extend PluginFixturesLoader
  end
end
