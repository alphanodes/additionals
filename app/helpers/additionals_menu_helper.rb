# frozen_string_literal: true

module AdditionalsMenuHelper
  def additionals_top_menu_setup
    return if AdditionalsPlugin.active_hrm?

    if Additionals.setting? :remove_mypage
      Redmine::MenuManager.map(:top_menu).delete(:my_page) if Redmine::MenuManager.map(:top_menu).exists?(:my_page)
    else
      handle_top_menu_item(:my_page, url: my_page_path, after: :home, onlyif: proc { User.current.logged? })
    end

    if Additionals.setting? :remove_help
      Redmine::MenuManager.map(:top_menu).delete(:help) if Redmine::MenuManager.map(:top_menu).exists?(:help)
    elsif User.current.logged?
      handle_top_submenu_item :help, url: '#', symbol: 'fas_question', last: true
      @additionals_help_items = additionals_help_menu_items
    else
      handle_top_menu_item :help, url: Redmine::Info.help_url, symbol: 'fas_question', last: true
    end
  end

  def handle_top_submenu_item(menu_name, **item)
    handle_top_menu_item menu_name, with_submenu: true, **item
  end

  def handle_top_menu_item(menu_name, url:, with_submenu: false, onlyif: nil,
                           name: nil, parent: nil, title: nil, symbol: nil, before: nil, after: nil, last: false)
    Redmine::MenuManager.map(:top_menu).delete(menu_name.to_sym) if Redmine::MenuManager.map(:top_menu).exists?(menu_name.to_sym)

    html_options = {}

    css_classes = []
    css_classes << 'top-submenu' if with_submenu
    css_classes << 'external' if url.include? '://'
    html_options[:class] = css_classes.join ' ' if css_classes.present?

    html_options[:title] = title if title.present?

    menu_options = { parent: parent.present? ? parent.to_sym : nil,
                     html: html_options }

    menu_options[:if] = onlyif if onlyif.present?

    menu_options[:caption] = if symbol.present? && name.present?
                               font_awesome_icon symbol, post_text: name
                             elsif symbol.present?
                               font_awesome_icon symbol
                             elsif name.present?
                               name.to_s
                             end

    if last
      menu_options[:last] = true
    elsif before.present?
      menu_options[:before] = before
    elsif after.present?
      menu_options[:after] = after
    else
      menu_options[:before] = :help
    end

    Redmine::MenuManager.map(:top_menu).push menu_name, url, **menu_options
  end

  def render_custom_top_menu_item
    items = additionals_build_custom_items
    return if items.empty?

    user_roles = Role.givable
                     .joins(members: :project)
                     .where(members: { user_id: User.current.id },
                            projects: { status: Project::STATUS_ACTIVE })
                     .distinct
                     .reorder(nil)
                     .ids

    items.each do |item|
      additionals_custom_top_menu_item item, user_roles
    end
  end

  def additionals_build_custom_items
    items = []
    Additionals::MAX_CUSTOM_MENU_ITEMS.times do |num|
      menu_name = "custom_menu#{num}"
      item = { menu_name: menu_name.to_sym,
               url: Additionals.setting("#{menu_name}_url"),
               name: Additionals.setting("#{menu_name}_name"),
               title: Additionals.setting("#{menu_name}_title"),
               roles: Additionals.setting("#{menu_name}_roles") }

      if item[:name].present? && item[:url].present? && item[:roles].present?
        items << item
      elsif Redmine::MenuManager.map(:top_menu).exists?(item[:menu_name])
        Redmine::MenuManager.map(:top_menu).delete(item[:menu_name])
      end
    end

    items
  end

  def additionals_custom_top_menu_item(item, user_roles)
    show_entry = false
    roles = item.delete :roles
    roles.each do |role|
      if user_roles.empty? && role.to_i == Role::BUILTIN_ANONYMOUS ||
         # if user is logged in and non_member is active in item, always show it
         User.current.logged? && role.to_i == Role::BUILTIN_NON_MEMBER
        show_entry = true
        break
      end

      user_roles.each do |user_role|
        if role.to_i == user_role
          show_entry = true
          break
        end
      end
      break if show_entry
    end

    menu_name = item.delete :menu_name
    if show_entry
      handle_top_menu_item menu_name, item
    elsif Redmine::MenuManager.map(:top_menu).exists?(menu_name)
      Redmine::MenuManager.map(:top_menu).delete(menu_name)
    end
  end

  def addtionals_help_plugin_items
    user_items = [{ title: 'Redmine Guide', url: Redmine::Info.help_url },
                  { title: "Redmine #{l :label_macro_plural}", url: additionals_macros_path }]

    admin_items = [{ title: "Additionals #{l :label_help_manual}",
                     url: 'https://additionals.readthedocs.io/en/latest/manual/' },
                   { title: 'Redmine Changelog',
                     url: "https://www.redmine.org/projects/redmine/wiki/Changelog_#{Redmine::VERSION::MAJOR}_#{Redmine::VERSION::MINOR}" },
                   { title: 'Redmine Upgrade',
                     url: 'https://www.redmine.org/projects/redmine/wiki/RedmineUpgrade' },
                   { title: 'Redmine Security Advisories',
                     url: 'https://www.redmine.org/projects/redmine/wiki/Security_Advisories' }]

    Redmine::Plugin.all.each do |plugin|
      next if plugin.id == :additionals

      plugin_item_base = nil

      begin
        plugin_item_base = plugin.id.to_s.camelize.constantize
      rescue LoadError
        Rails.logger.debug { "Ignore plugin #{plugin.id} for help integration" }
      rescue StandardError => e
        raise e unless e.class.to_s == 'NameError'
      end

      plugin_item = plugin_item_base.try :additionals_help_items unless plugin_item_base.nil?
      plugin_item = additionals_help_items_fallbacks plugin.id if plugin_item.nil?

      next if plugin_item.nil?

      plugin_item.each do |temp_item|
        u_items = if !temp_item[:manual].nil? && temp_item[:manual]
                    { title: "#{temp_item[:title]} #{l :label_help_manual}", url: temp_item[:url] }
                  else
                    { title: temp_item[:title], url: temp_item[:url] }
                  end

        if !temp_item[:admin].nil? && temp_item[:admin]
          admin_items << u_items
        else
          user_items << u_items
        end
      end
    end

    { user: user_items, admin: admin_items }
  end

  def additionals_help_menu_items
    plugin_items = addtionals_help_plugin_items
    pages = plugin_items[:user].sort_by { |k| k[:title] }

    if User.current.admin?
      pages << { title: '-' }
      pages += plugin_items[:admin].sort_by { |k| k[:title] }
    end

    s = []
    pages.each_with_index do |item, idx|
      s << if item[:title] == '-'
             tag.li tag.hr
           else
             html_options = { class: +"help_item_#{idx}" }
             if item[:url].include? '://'
               html_options[:class] << ' external'
               html_options[:target] = '_blank'
             end
             tag.li link_to(item[:title], item[:url], html_options)
           end
    end
    safe_join s
  end

  # Plugin help items definition for plugins,
  # which do not have additionals_help_menu_items integration
  def additionals_help_items_fallbacks(plugin_id)
    plugins = { redmine_drawio: [{ title: 'draw.io usage',
                                   url: 'https://github.com/mikitex70/redmine_drawio#usage' }],
                redmine_contacts: [{ title: 'Redmine CRM',
                                     url: 'https://www.redmineup.com/pages/help/crm',
                                     admin: true }],
                redmine_contacts_helpdesk: [{ title: 'Redmine Helpdesk',
                                              url: 'https://www.redmineup.com/pages/help/helpdesk',
                                              admin: true }],
                redmine_ldap_sync: [{ title: 'Redmine LDAP',
                                      url: 'https://www.redmine.org/projects/redmine/wiki/RedmineLDAP',
                                      admin: true },
                                    { title: 'Redmine LDAP Sync',
                                      url: 'https://github.com/thorin/redmine_ldap_sync/blob/master/README.md',
                                      admin: true }] }
    plugins[plugin_id]
  end
end
