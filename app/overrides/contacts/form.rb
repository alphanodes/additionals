# frozen_string_literal: true

unless Redmine::Plugin.installed? 'redmine_servicedesk'
  if defined?(CONTACTS_VERSION_TYPE) && CONTACTS_VERSION_TYPE == 'PRO version'
    Deface::Override.new virtual_path: 'contacts/_form',
                         name: 'contacts-pro-form-hook',
                         insert_bottom: 'div#contact_data',
                         original: 'df6cae24cfd26e5299c45c427fbbd4e5f23c313e',
                         partial: 'hooks/view_contacts_form'
  else
    Deface::Override.new virtual_path: 'contacts/_form',
                         name: 'contacts-form-hook',
                         insert_bottom: 'div#contact_data',
                         original: '217049684a0bcd7e404dc6b5b2348aae47ac8a72',
                         partial: 'hooks/view_contacts_form'
  end
end
