Deface::Override.new virtual_path: 'issues/_action_menu',
                     name:         'replace-log-time-link',
                     replace:      "erb[loud]:contains('if User.current.allowed_to?(:log_time, @project)')",
                     original:     '4bbf065b9f960687e07f76e7232eb21bf183a981',
                     partial:      'issues/log_time_link'
