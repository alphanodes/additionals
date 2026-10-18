# frozen_string_literal: true

module DashboardBlocks
  class ProjectMembersBlock < Base
    block_id 'projectmembers'
    label :label_member_plural
    dashboards :project
    partial 'projects/members_box'
    no_settings!
  end
end
