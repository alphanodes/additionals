# frozen_string_literal: true

Deface::Override.new virtual_path: 'admin/info',
                     name: 'add-system_info',
                     insert_after: 'table.list',
                     original: '73b55ca692bcf4db9ecb7a16ec6d6f9e46f08a90',
                     partial: 'admin/system_info'
