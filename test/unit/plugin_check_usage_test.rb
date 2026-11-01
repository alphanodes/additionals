# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class PluginCheckUsageTest < Additionals::TestCase
  Usage = Additionals::PluginCheckUsage

  def setup
    super
    @directory = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry @directory
    super
  end

  def test_load_time_checks_need_force
    write 'lib/plugin_x.rb', <<~RUBY
      module PluginX
        CLASS_BODY = AdditionalsPlugin.active_db?
        FORCED = AdditionalsPlugin.active_db?(force: true)

        def self.setup
          loader.add_patch 'Foo' if AdditionalsPlugin.active_passwords?
        end

        def runtime
          AdditionalsPlugin.active_db?
        end

        scope :visible, lambda { AdditionalsPlugin.active_hrm? }
        scope :other, -> { AdditionalsPlugin.active_hrm? }
        menu if: proc { AdditionalsPlugin.active_hrm? }
        CALLBACK = Proc.new { AdditionalsPlugin.active_hrm? }
      end
    RUBY
    write 'db/migrate/001_foo.rb', <<~RUBY
      class Foo < ActiveRecord::Migration[7.2]
        def down
          return unless AdditionalsPlugin.active_automation?
        end
      end
    RUBY

    assert_equal ['db/migrate/001_foo.rb:3 active_automation?',
                  'lib/plugin_x.rb:2 active_db?',
                  'lib/plugin_x.rb:6 active_passwords?'],
                 Usage.unforced_load_time_checks(@directory).sort
  end

  def test_direct_installed_checks_ignore_comments_and_exceptions
    write 'app/views/foo/_bar.html.slim', "- if Redmine::Plugin.installed? 'redmine_db'\n"
    write 'lib/plugin_x.rb', "# use Redmine::Plugin.installed? only in tests\n"
    write 'app/models/own.rb', "Redmine::Plugin.installed? 'redmine_db'\n"
    write 'init.rb', "Redmine::Plugin.register :plugin_x do\nend\n"

    assert_equal ['app/views/foo/_bar.html.slim'], Usage.direct_installed_checks(@directory, except: %w[app/models/own.rb])
  end

  private

  def write(file, content)
    path = File.join @directory, file
    FileUtils.mkdir_p File.dirname(path)
    File.write path, content
  end
end
