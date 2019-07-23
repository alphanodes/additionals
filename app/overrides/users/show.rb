Deface::Override.new virtual_path: 'users/show',
                     name: 'user-show-info-hook',
                     insert_top: 'div.splitcontentleft ul:first-child',
                     original: 'aff8d775275e3f33cc45d72b8e2896144be4beff',
                     partial: 'hooks/view_users_show'
Deface::Override.new virtual_path: 'users/show',
                     name: 'user-contextual-hook',
                     insert_bottom: 'div.contextual',
                     original: 'a01f2e6431910bf692e4208a769abeb2fe4215e8',
                     partial: 'hooks/view_users_contextual'
