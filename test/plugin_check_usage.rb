# frozen_string_literal: true

require 'prism'

module Additionals
  # Finds checks of AdditionalsPlugin.active_<name>? that run once while a file
  # is loaded but still look at the module lock. The lock is a setting an
  # administrator may change while the process runs, so a patch, a hook or an
  # association decided at load time has to depend on the installation only,
  # which force: true asks for. Plain Ruby without Rails, like LocaleKeyUsage.
  #
  # Load time means a class or module body, the setup of a plugin and every
  # migration. Bodies of other methods, lambdas and procs run later.
  module PluginCheckUsage
    LOAD_TIME_METHODS = %i[setup].freeze
    DEFERRED_BLOCK_CALLS = %i[lambda proc].freeze

    class Visitor < Prism::Visitor
      attr_reader :hits

      def initialize(path, migration:)
        super()
        @path = path
        @migration = migration
        @deferred = 0
        @hits = []
      end

      def visit_def_node(node)
        deferred(!@migration && LOAD_TIME_METHODS.exclude?(node.name)) { super }
      end

      def visit_lambda_node(node)
        deferred(true) { super }
      end

      def visit_call_node(node)
        record node if unforced_check? node
        deferred(deferred_block?(node)) { super }
      end

      private

      def deferred(active)
        @deferred += 1 if active
        yield
      ensure
        @deferred -= 1 if active
      end

      def deferred_block?(node)
        return false unless node.block

        DEFERRED_BLOCK_CALLS.include?(node.name) ||
          (node.name == :new && node.receiver.is_a?(Prism::ConstantReadNode) && node.receiver.name == :Proc)
      end

      def unforced_check?(node)
        @deferred.zero? &&
          node.name.to_s.start_with?('active_') &&
          node.receiver.is_a?(Prism::ConstantReadNode) && node.receiver.name == :AdditionalsPlugin &&
          !forced?(node)
      end

      def forced?(node)
        node.arguments&.arguments&.any? Prism::KeywordHashNode
      end

      def record(node)
        @hits << "#{@path}:#{node.location.start_line} #{node.name}"
      end
    end

    class << self
      # Load time checks without force: true in the Ruby files below +directory+
      def unforced_load_time_checks(directory)
        Dir.glob('{app,lib,db}/**/*.rb', base: directory).flat_map do |file|
          visitor = Visitor.new file, migration: file.start_with?('db/migrate/')
          Prism.parse_file(File.join(directory, file)).value.accept visitor
          visitor.hits
        end
      end

      # Source files below +directory+ that ask Redmine::Plugin.installed?
      # directly; comments do not count
      def direct_installed_checks(directory, except: [])
        files = Dir.glob('{app,lib,db,config}/**/*.{rb,rake,slim,erb}', base: directory) + %w[init.rb]
        (files - except).select do |file|
          path = File.join directory, file
          File.file?(path) && File.foreach(path).any? do |line|
            line.include?('Redmine::Plugin.installed?') && !line.lstrip.start_with?('#')
          end
        end
      end
    end
  end
end
