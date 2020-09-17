unless Redmine::Plugin.installed? 'redmine_servicedesk'
  # redmine_contacts does not provide hook
  Deface::Override.new virtual_path: 'contacts/_form',
                       name: 'contacts-form-hook',
                       insert_bottom: 'div#contact_data',
                       original: 'df6cae24cfd26e5299c45c427fbbd4e5f23c313e',
                       partial: 'hooks/view_contacts_form'
end
