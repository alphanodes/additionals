# frozen_string_literal: true

module ContactsForm
  # The anchor comes from the light version of RedmineUP's contacts plugin, the
  # only one we keep. It used to be the PRO one - back then the override existed
  # twice, because both versions ship a different contacts/_form.
  #
  # No CI validates this anchor: the condition needs RedmineUP's contacts plugin
  # present and ours absent, and no pipeline installs that combination. It is
  # checked by running the additionals deface test in an instance that has it
  # (redmineup, redmine_jac) - worth repeating whenever contacts/_form changes.
  if defined?(RedmineContacts) && !defined?(RedmineServicedesk)
    Deface::Override.new virtual_path: 'contacts/_form',
                         name: 'additionals-contacts-form-hook',
                         insert_bottom: 'div#contact_data',
                         original: '72f1567f63cd4871d835a302ec750004c298e38f',
                         partial: 'hooks/view_contacts_form'
  end
end
