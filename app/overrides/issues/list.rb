# frozen_string_literal: true

Deface::Override.new virtual_path: 'issues/_list',
                     name: 'list-issue-back-url',
                     replace: 'erb[loud]:contains("hidden_field_tag \'back_url\'")',
                     original: '6652d55078bb57ac4614e456b01f8a203b8096ec',
                     text: '<%= query_list_back_url_tag @project %>'
