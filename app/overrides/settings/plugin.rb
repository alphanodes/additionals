if Redmine::VERSION.to_s >= '4.1'
  # Fix settings plugin bug starting with https://www.redmine.org/issues/33339
  Deface::Override.new virtual_path: 'settings/plugin',
                       name: 'fix-box-settings-plugin-bug',
                       remove_from_attributes: 'div.box.tabular.settings',
                       attributes: { class: 'settings' },
                       original: '4778c00d28a60d776afc3e4b69112d6b892ec9ae'
end
