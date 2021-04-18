# frozen_string_literal: true

Deface::Override.new virtual_path: 'reports/_simple',
                     name: 'report-simple-user-scope',
                     insert_before: 'erb[silent]:contains("rows.empty?")',
                     original: '0c85cc752700d7f2bf08b3b9b30f59d8eddc443b',
                     partial: 'reports/additionals_simple'
