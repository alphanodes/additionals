# frozen_string_literal: true

module UsersShow
  unless defined? RedmineHrm
    Deface::Override.new virtual_path: 'users/show',
                         name: 'user-show-info-hook',
                         insert_top: 'div.splitcontentleft ul:first-child',
                         original: '9a47f38a2f2efe7ab824dd8d435db172a2344aa8',
                         partial: 'hooks/view_users_show_info'

    Deface::Override.new virtual_path: 'users/show',
                         name: 'user-contextual-hook',
                         insert_bottom: 'div.contextual',
                         original: '9d6a7ad6ba0addc68c6b4f6c3b868511bc8eb542',
                         partial: 'hooks/view_users_show_contextual'
  end
end
