Deface::Override.new virtual_path: 'welcome/index',
                     name: 'add-welcome-top-content',
                     insert_before: "div.#{Redmine::VERSION.to_s >= '4.1' ? 'splitcontent' : 'splitcontentleft'}",
                     original: 'e7de0a2e88c5ccb4d1feb7abac239e4b669babed',
                     partial: 'welcome/overview_top'
Deface::Override.new virtual_path: 'welcome/index',
                     name: 'view-welcome-index-bottom-hook',
                     insert_after: "div.#{Redmine::VERSION.to_s >= '4.1' ? 'splitcontent' : 'splitcontentright'}",
                     original: 'dd470844bcaa4d7c9dc66e70e6c0c843d42969bf',
                     partial: 'hooks/view_welcome_index_bottom'
Deface::Override.new virtual_path: 'welcome/index',
                     name: 'remove-welcome-news',
                     replace: 'div.news',
                     original: '163f5df8f0cb2d5009d7f57ad38174ed29201a1a',
                     partial: 'welcome/overview_news'
