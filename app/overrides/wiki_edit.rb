# frozen_string_literal: true

module WikiEdit
  if Additionals.redmine6?
    Deface::Override.new virtual_path: 'wiki/edit',
                         name: 'wiki-edit',
                         insert_before: 'fieldset',
                         original: '8c202edfea8a0a74e4c3c0c4ae53e129b1d2b1ee',
                         partial: 'hooks/view_wiki_form_bottom'
  else
    Deface::Override.new virtual_path: 'wiki/edit',
                         name: 'wiki-edit',
                         insert_before: 'fieldset',
                         original: 'ededb6cfd5adfe8a9723d00ce0ee23575c7cc44c',
                         partial: 'hooks/view_wiki_form_bottom'
  end
end
