# frozen_string_literal: true

Deface::Override.new virtual_path: 'issues/_edit',
                     name: 'edit-issue-permission',
                     replace: 'erb[silent]:contains("User.current.allowed_to?(:log_time, @project)")',
                     original: '98560fb12bb71f775f2a7fd1884c97f8cd632cd3',
                     text: '<% if User.current.allowed_to?(:log_time, @project) && @issue.log_time_allowed? %>'
