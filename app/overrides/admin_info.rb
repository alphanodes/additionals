# frozen_string_literal: true

module AdminInfo
  Deface::Override.new virtual_path: 'admin/info',
                       name: 'add-system_info',
                       insert_after: 'table.list',
                       original: '3fa222a7a7d371fd24314cd0c3fc29b490139cf9',
                       partial: 'admin/system_info'
end
