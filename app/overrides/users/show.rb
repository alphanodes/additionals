Deface::Override.new virtual_path: 'users/show',
                     name: 'user-show-info-hook',
                     insert_top: 'div.splitcontentleft ul:first-child',
                     original: 'aff8d775275e3f33cc45d72b8e2896144be4beff',
                     text: '<%= call_hook(:view_users_show_info, user: @user) %>'
Deface::Override.new virtual_path: 'users/show',
                     name: 'user-contextual-hook',
                     insert_bottom: 'div.contextual',
                     original: 'a01f2e6431910bf692e4208a769abeb2fe4215e8',
                     text: '<%= call_hook(:view_users_show_contextual, user: @user) %>'
