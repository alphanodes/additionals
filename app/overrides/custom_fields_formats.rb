# frozen_string_literal: true

module CustomFieldsFormats
  Deface::Override.new virtual_path: 'custom_fields/formats/_text',
                       name: 'custom_fields-formats-text',
                       replace: 'erb[silent]:contains(\'if @custom_field.class.name == "IssueCustomField"\')',
                       original: 'b1555e66104390d843ad37d44f7d6a3132f1a2d5',
                       closing_selector: "erb[silent]:contains('end')",
                       partial: 'custom_fields/formats/additionals_text'
end
