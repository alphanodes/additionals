# frozen_string_literal: true

# Dashboard blocks as classes, a file each in lib/dashboard_blocks/ of its
# plugin, see RedminePluginKit::Extensions. DashboardContent builds its block
# definitions from them.
module DashboardBlocks
  class << self
    # Called in the setup of additionals, at boot and after every code reload
    def load!
      RedminePluginKit::Extensions.load! 'dashboard_blocks'
      # A plugin changes the block of another one by a subclass with the same
      # id, which takes its place. Two unrelated blocks with one id stop the boot.
      @all = RedminePluginKit::Extensions.classes Base, key: :block_id
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
