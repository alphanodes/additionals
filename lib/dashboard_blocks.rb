# frozen_string_literal: true

# Dashboard blocks as classes, a file each in lib/dashboard_blocks/ of its
# plugin, see RedminePluginKit::Extensions. DashboardContent builds its block
# definitions from them.
module DashboardBlocks
  # A plugin still adds its blocks by a block_definitions method
  class PatchError < StandardError; end

  class << self
    # Called in the setup of additionals, at boot and after every code reload
    def load!
      RedminePluginKit::Extensions.load! 'dashboard_blocks'
      # A plugin changes the block of another one by a subclass with the same
      # id, which takes its place. Two unrelated blocks with one id stop the boot.
      @all = RedminePluginKit::Extensions.classes Base, key: :block_id
      check_patches_after_boot
    end

    # Plugins patch in their setup, which may run after the one of additionals
    def check_patches_after_boot
      return if @check_patches_registered

      @check_patches_registered = true
      Rails.application.config.after_initialize { check_patches! }
    end

    # Blocks are classes, block_definitions of a dashboard content is gone: a
    # plugin defining it would add nothing without noticing
    def check_patches!(contents = [DashboardContent, *DashboardContent.descendants])
      patched = contents.filter_map do |content|
        next unless content.method_defined? :block_definitions

        "#{content.instance_method(:block_definitions).owner} in #{content}"
      end
      return if patched.empty?

      raise PatchError, "block_definitions is defined (#{patched.to_comma_list}), dashboard blocks are classes " \
                        'in lib/dashboard_blocks/ of a plugin, see docs/dashboards.md of additionals'
    end

    # Read at runtime only: the setup of a plugin may run before load!
    def all
      @all || raise('Dashboard blocks are read before DashboardBlocks.load!')
    end

    def find(block_id)
      all.detect { |block| block.block_id == block_id.to_s }
    end

    # The blocks a dashboard content offers, with the content
    def for(content)
      all.filter_map { |block| block.new content if block.offered_on? content.dashboard_type }
    end
  end
end
