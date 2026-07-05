# frozen_string_literal: true

module WikiEdit
  Deface::Override.new virtual_path: 'wiki/edit',
                       name: 'wiki-edit',
                       insert_before: 'fieldset',
                       original: '00ce4e80d56c9bfb7d743b040266a725336fe773',
                       partial: 'hooks/view_wiki_form_bottom'
end
