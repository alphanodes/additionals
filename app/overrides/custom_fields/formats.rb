# frozen_string_literal: true

Deface::Override.new virtual_path: 'custom_fields/formats/_text',
                     name: 'custom_fields-formats-text',
                     replace: 'erb[silent]:contains(\'if @custom_field.class.name == "IssueCustomField"\')',
                     original: '5e0fbf8e8156bf1514cbada3dbaca9afc3c19bbb',
                     closing_selector: "erb[silent]:contains('end')",
                     partial: 'custom_fields/formats/additionals_text.html.slim'
