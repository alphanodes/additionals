# frozen_string_literal: true

module WikiEdit
  original_hash = if Redmine::VERSION::BRANCH == 'devel'
                    '00ce4e80d56c9bfb7d743b040266a725336fe773'
                  else
                    '8c202edfea8a0a74e4c3c0c4ae53e129b1d2b1ee'
                  end

  Deface::Override.new virtual_path: 'wiki/edit',
                       name: 'wiki-edit',
                       insert_before: 'fieldset',
                       original: original_hash,
                       partial: 'hooks/view_wiki_form_bottom'
end
