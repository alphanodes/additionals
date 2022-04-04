# frozen_string_literal: true

module IssuesEdit
  Deface::Override.new virtual_path: 'issues/_edit',
                       name: 'edit-issue-permission',
                       replace: 'erb[silent]:contains("User.current.allowed_to?(:log_time, @issue.project)")',
                       original: '3d5af3ecf77c96475751ab78e0081bc6cac07df7',
                       text: '<% if User.current.allowed_to?(:log_time, @issue.project) && @issue.log_time_allowed? %>'
end
