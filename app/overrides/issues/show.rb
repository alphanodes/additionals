Deface::Override.new virtual_path: 'issues/_action_menu',
                     name: 'show-issue-log-time',
                     replace: 'erb[loud]:contains("User.current.allowed_to?(:log_time, @project)")',
                     original: '4bbf065b9f960687e07f76e7232eb21bf183a981',
                     partial: 'issues/additionals_action_menu_log_time'
Deface::Override.new virtual_path: 'issues/_action_menu',
                     name: 'add-issue-assign-to-me',
                     insert_bottom: 'div.contextual',
                     original: '44ef032156db0dfdb67301fdb9ef8901abeca18a',
                     partial: 'issues/additionals_action_menu'
