# frozen_string_literal: true

module ContactsForm
  if defined?(RedmineContacts) && !defined?(RedmineServicedesk)
    Deface::Override.new virtual_path: 'contacts/_form',
                         name: 'additionals-contacts-pro-form-hook',
                         insert_bottom: 'div#contact_data',
                         original: '72f1567f63cd4871d835a302ec750004c298e38f',
                         partial: 'hooks/view_contacts_form'
  end
end
