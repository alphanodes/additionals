# frozen_string_literal: true

module WikiShow
  Deface::Override.new virtual_path: 'wiki/show',
                       name: 'wiki-show',
                       sequence: 1,
                       insert_before: 'p.wiki-update-info',
                       original: '39c0ff8f0b6a468264526af5046c3c6db7e94997',
                       partial: 'hooks/view_wiki_show_bottom'

  Deface::Override.new virtual_path: 'wiki/show',
                       name: 'wiki-show-action-dropdown',
                       insert_after: 'erb[loud]:contains("label_history")',
                       original: '83d97f2d91c682d3329bc2df00856cc6f6cc4b09',
                       partial: 'hooks/view_wiki_show_action_dropdown'
end
