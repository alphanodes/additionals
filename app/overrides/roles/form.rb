# frozen_string_literal: true

Deface::Override.new virtual_path: 'roles/_form',
                     name: 'roles-form-hide',
                     insert_before: 'p.manage_members_shown',
                     original: '7413482e01a07b5615be1900b974fee87224cb47',
                     partial: 'roles/additionals_form'
