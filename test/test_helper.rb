# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start :rails do
    add_filter 'init.rb'
    root File.expand_path "#{File.dirname __FILE__}/.."
  end
end

require 'minitest/reporters'
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new, Minitest::Reporters::JUnitReporter.new]

require File.expand_path "#{File.dirname __FILE__}/../../../test/test_helper"
require File.expand_path "#{File.dirname __FILE__}/global_fixtures_helper"
require File.expand_path "#{File.dirname __FILE__}/global_test_helper"
require File.expand_path "#{File.dirname __FILE__}/crud_controller_base"

module Additionals
  module TestHelper
    include Additionals::GlobalTestHelper

    def prepare_tests
      Role.where(id: [1, 2]).find_each do |r|
        r.permissions << :save_dashboards
        r.save
      end

      Role.where(id: [1]).find_each do |r|
        r.permissions << :share_dashboards
        r.permissions << :set_system_dashboards
        r.permissions << :show_hidden_roles_in_memberbox
        r.save
      end

      Project.where(id: [1, 2]).find_each do |project|
        EnabledModule.create project:, name: 'issue_tracking'
      end
    end

    def emoji_heart_tag
      '<additionals-emoji title="red heart" data-name="heart" data-unicode-version="6.0">❤️</additionals-emoji>'
    end
  end

  module PluginFixturesLoader
    include Additionals::GlobalFixturesHelper

    def plugin_fixtures_list
      custom = %i[dashboards dashboard_roles]
      custom += %i[hrm_user_types hrm_working_calendars] if AdditionalsPlugin.active_hrm?
      custom
    end
  end

  class HelperTest < Redmine::HelperTest
    include Additionals::TestHelper
    extend PluginFixturesLoader
    fixtures(*fixtures_list)
  end

  class ControllerTest < Redmine::ControllerTest
    include Additionals::TestHelper
    extend PluginFixturesLoader
    fixtures(*fixtures_list)
  end

  class TestCase < ActiveSupport::TestCase
    include Additionals::TestHelper
    extend PluginFixturesLoader
    fixtures(*fixtures_list)
  end

  class IntegrationTest < Redmine::IntegrationTest
    include Additionals::TestHelper
    extend PluginFixturesLoader
    fixtures(*fixtures_list)
  end

  class ApiTest < Redmine::ApiTest::Base
    include Additionals::TestHelper
    extend PluginFixturesLoader
    fixtures(*fixtures_list)
  end
end
