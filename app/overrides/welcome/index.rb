if Redmine::VERSION.to_s >= '4.1'
  Deface::Override.new virtual_path: 'welcome/index',
                       name: 'add-welcome-top-content',
                       insert_before: 'div.splitcontent',
                       original: '977b0ccc97c05ab90e4c81eed269c5a03bac4f91',
                       partial: 'welcome/overview_top'
  Deface::Override.new virtual_path: 'welcome/index',
                       name: 'view-welcome-index-bottom-hook',
                       insert_after: 'div.splitcontent',
                       original: '977b0ccc97c05ab90e4c81eed269c5a03bac4f91',
                       text: '<%= call_hook(:view_welcome_index_bottom) %>'
else
  Deface::Override.new virtual_path: 'welcome/index',
                       name: 'add-welcome-top-content',
                       insert_before: 'div.splitcontentleft',
                       original: 'e7de0a2e88c5ccb4d1feb7abac239e4b669babed',
                       partial: 'welcome/overview_top'
  Deface::Override.new virtual_path: 'welcome/index',
                       name: 'view-welcome-index-bottom-hook',
                       insert_after: 'div.splitcontentright',
                       original: 'dd470844bcaa4d7c9dc66e70e6c0c843d42969bf',
                       text: '<%= call_hook(:view_welcome_index_bottom) %>'
end
