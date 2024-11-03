# frozen_string_literal: true

module WikiIndex
  Deface::Override.new virtual_path: 'wiki/index',
                       name: 'reporting-add-wiki-index-pdf-options-modal',
                       insert_before: 'erb[silent]:contains("content_for :header_tags")',
                       original: '991dfe298b3aac07f291fcbabaebbd32b0cec720',
                       partial: 'hooks/view_wiki_index_bottom'
end
