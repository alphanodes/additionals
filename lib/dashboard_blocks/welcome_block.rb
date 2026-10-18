# frozen_string_literal: true

module DashboardBlocks
  class WelcomeBlock < Base
    block_id 'welcome'
    label :setting_welcome_text
    dashboards :welcome
    partial 'dashboards/blocks/welcome'
    no_settings!
  end
end
