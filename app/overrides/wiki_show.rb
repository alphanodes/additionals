# frozen_string_literal: true

module WikiShow
  Deface::Override.new virtual_path: 'wiki/show',
                       name: 'wiki-show',
                       insert_before: 'p.wiki-update-info',
                       original: '20f7afc86f7b80234f9f5a53b1ceb6414f76d822',
                       partial: 'hooks/view_wiki_show_bottom'
end
