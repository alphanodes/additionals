# frozen_string_literal: true

module WikiEdit
  # The attachment fieldset this override is anchored to is not the same in every
  # redmine version: master hands the filename to file_type_icon, 7.0 does not,
  # and that changes the hash deface validates the anchor against.
  #
  # Once that change arrives in a stable release, the branch no longer tells the
  # two apart and this has to be revisited - the failing hash test says so.
  # Kept in local variables: this file is evaluated more than once per boot, and
  # constants would warn about being reinitialized every time.
  original = if Redmine::VERSION::BRANCH == 'devel'
               'bd179cc289457e50624034cb1615d0004f8fa6eb'
             else
               '00ce4e80d56c9bfb7d743b040266a725336fe773'
             end

  Deface::Override.new virtual_path: 'wiki/edit',
                       name: 'wiki-edit',
                       insert_before: 'fieldset',
                       original:,
                       partial: 'hooks/view_wiki_form_bottom'
end
