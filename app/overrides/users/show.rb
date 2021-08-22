# frozen_string_literal: true

unless Redmine::Plugin.installed? 'redmine_hrm'
  if Redmine::VERSION.to_s >= '4.2'
    Deface::Override.new virtual_path: 'users/show',
                         name: 'user-show-info-hook',
                         insert_top: 'div.splitcontentleft ul:first-child',
                         original: '9a47f38a2f2efe7ab824dd8d435db172a2344aa8',
                         partial: 'hooks/view_users_show_info'
  else
    Deface::Override.new virtual_path: 'users/show',
                         name: 'user-show-info-hook',
                         insert_top: 'div.splitcontentleft ul:first-child',
                         original: '743d616ab7942bb6bc65bd00626b6a5143247a37',
                         partial: 'hooks/view_users_show_info'
  end

  Deface::Override.new virtual_path: 'users/show',
                       name: 'user-contextual-hook',
                       insert_bottom: 'div.contextual',
                       original: '9d6a7ad6ba0addc68c6b4f6c3b868511bc8eb542',
                       partial: 'hooks/view_users_show_contextual'
end
