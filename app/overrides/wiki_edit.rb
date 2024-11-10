# frozen_string_literal: true

module WikiEdit
  Deface::Override.new virtual_path: 'wiki/edit',
                       name: 'wiki-edit',
                       insert_before: 'fieldset',
                       original: '8c202edfea8a0a74e4c3c0c4ae53e129b1d2b1ee',
                       partial: 'hooks/view_wiki_form_bottom'
end
