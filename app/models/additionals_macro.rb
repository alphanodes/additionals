# frozen_string_literal: true

class AdditionalsMacro
  class << self
    def all(only_names: false, filtered: [], controller_only: nil)
      all = Redmine::WikiFormatting::Macros.available_macros
      macros = {}
      macro_list = []

      # needs to run every request (for each user once)
      permissions = build_permissions controller_only: controller_only

      if filtered.present?
        filtered << 'hello_world'
      else
        filtered = ['hello_world']
      end

      all.each do |macro, macro_options|
        next if filtered.include? macro.to_s
        next unless macro_allowed macro, permissions

        macro_list << macro.to_s
        macros[macro] = macro_options
      end

      if only_names
        macro_list.sort
      else
        macros.sort
      end
    end

    private

    def macro_allowed(macro, permissions)
      permissions.each do |permission|
        next if permission[:list].exclude? macro
        return false unless permission[:access]
      end

      true
    end

    def build_permissions(controller_only: nil)
      gpermission = []
      macro_permissions.each do |permission|
        permission[:access] = if controller_only &&
                                 permission[:controller].present? &&
                                 controller_only.to_sym != permission[:controller]
                                false
                              else
                                User.current.allowed_to? permission[:permission], nil, global: true
                              end
        gpermission << permission
      end

      gpermission
    end

    def macro_permissions
      [{ list: %i[issue issue_name_link],
         permission: :view_issues },
       { list: %i[password password_query password_tag password_tag_count],
         permission: :view_passwords },
       { list: %i[contact deal contact_avatar contact_note contact_plain],
         permission: :view_contacts },
       { list: %i[db db_query db_tag db_tag_count],
         permission: :view_db_entries },
       { list: %i[child_pages last_updated_at last_updated_by lastupdated_at lastupdated_by
                  new_page recently_updated recent comments comment_form tags taggedpages tagcloud
                  show_count count vote show_vote terms_accept terms_reject],
         permission: :view_wiki_pages,
         controller: :wiki },
       { list: %i[mail send_file],
         permission: :view_helpdesk_tickets },
       { list: %i[kb article_id article category],
         permission: :view_kb_articles }]
    end
  end
end
