Deface::Override.new virtual_path: 'users/show',
                     name: 'user-show-info-hook',
                     insert_top: 'div.splitcontentleft ul:first-child',
                     original: 'aff8d775275e3f33cc45d72b8e2896144be4beff',
                     partial: 'hooks/view_users_show'
Deface::Override.new virtual_path: 'users/show',
                     name: 'user-contextual-hook',
                     insert_bottom: 'div.contextual',
                     original: '9d6a7ad6ba0addc68c6b4f6c3b868511bc8eb542',
                     partial: 'hooks/view_users_contextual'
