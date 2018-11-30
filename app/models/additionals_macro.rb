class AdditionalsMacro
  # options:
  # - project
  # - only_names
  def self.all(options = {})
    all = Redmine::WikiFormatting::Macros.available_macros
    options[:only_names] = false unless options[:only_names]
    macros = {}
    macro_list = []

    global_permission = { view_issues: User.current.allowed_to?(:view_issues, nil, global: true),
                          view_db_entries: User.current.allowed_to?(:view_db_entries, nil, global: true),
                          view_passwords: User.current.allowed_to?(:view_password, nil, global: true),
                          view_contacts: User.current.allowed_to?(:view_contacts, nil, global: true) }

    all.each do |macro, macro_options|
      next if macro == :hello_world
      next unless macro_allowed(macro, options, global_permission)

      macro_list << macro.to_s
      macros[macro] = macro_options
    end

    if options[:only_names]
      macro_list.sort
    else
      macros.sort
    end
  end

  def self.macro_allowed(macro, options, global_permission)
    return false unless check_macro_permission(macro,
                                               options,
                                               global_permission,
                                               names: [:issue], permission: :view_issues)
    return false unless check_macro_permission(macro,
                                               options,
                                               global_permission,
                                               names: %i[password password_query password_tag password_tag_count], permission: :view_passwords)
    return false unless check_macro_permission(macro,
                                               options,
                                               global_permission,
                                               names: %i[contact deal contact_avatar contact_note contact_plain], permission: :view_contacts)
    return false unless check_macro_permission(macro,
                                               options,
                                               global_permission,
                                               names: %i[db db_query db_tag db_tag_count], permission: :view_db_entries)

    true
  end

  def self.check_macro_permission(macro, options, global_permission, check)
    names = check[:names]
    permission = check[:permission]
    return true if names.exclude?(macro)

    if options[:project]
      return true if User.current.allowed_to?(permission, options[:project])
    elsif global_permission[permission]
      return true
    end
  end
end
