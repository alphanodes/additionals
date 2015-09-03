  Deface::Override.new :virtual_path => 'welcome/index',
                     :name           => 'remove-welcome-latest_projects',
                     :original       =>'bd5d94c8882c7f599059c917195497b10d519b64',
                     :replace        => 'div.projects',
                     :partial        => 'welcome/remove_projects'
