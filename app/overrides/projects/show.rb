Deface::Override.new virtual_path: 'projects/show',
                     name: 'view-projects-show-bottom-hook',
                     insert_after: "div.#{Redmine::VERSION.to_s >= '4.1' ? 'splitcontent' : 'splitcontentright'}",
                     original: '8cd4d1b38e8afcb4665dbfea661b7048fbd92cf7',
                     text: '<%= call_hook(:view_projects_show_bottom, project: @project) %>'
