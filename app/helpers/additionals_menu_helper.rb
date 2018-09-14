module AdditionalsMenuHelper
  def additionals_top_menu_setup
    return unless User.current.try(:hrm_user_type_id).nil?

    if Additionals.setting?(:remove_mypage)
      Redmine::MenuManager.map(:top_menu).delete(:my_page) if Redmine::MenuManager.map(:top_menu).exists?(:my_page)
    else
      handle_top_menu_item(:my_page, url: my_path, after: :home, if: proc { User.current.logged? })
    end

    if Additionals.setting?(:remove_help)
      Redmine::MenuManager.map(:top_menu).delete(:help) if Redmine::MenuManager.map(:top_menu).exists?(:help)
    elsif User.current.logged?
      handle_top_menu_item(:help, url: '#', symbol: 'fas_question', last: true)
      @additionals_help_items = additionals_help_menu_items
    else
      handle_top_menu_item(:help, url: Redmine::Info.help_url, symbol: 'fas_question', last: true)
    end
  end

  def handle_top_menu_item(menu_name, item)
    Redmine::MenuManager.map(:top_menu).delete(menu_name.to_sym) if Redmine::MenuManager.map(:top_menu).exists?(menu_name.to_sym)

    html_options = {}
    html_options[:class] = 'external' if item[:url].include? '://'
    html_options[:title] = item[:title] if item[:title].present?

    menu_options = { parent: item[:parent].present? ? item[:parent].to_sym : nil,
                     html: html_options }

    menu_options[:if] = menu_options[:if] if menu_options[:if].present?

    menu_options[:caption] = if item[:symbol].present? && item[:name].present?
                               font_awesome_icon(item[:symbol], post_text: item[:name])
                             elsif item[:symbol].present?
                               font_awesome_icon(item[:symbol])
                             elsif item[:name].present?
                               item[:name].to_s
                             end

    if item[:last].present? && item[:last]
      menu_options[:last] = true
    elsif item[:before].present?
      menu_options[:before] = item[:before]
    elsif item[:after].present?
      menu_options[:after] = item[:after]
    else
      menu_options[:before] = :help
    end

    Redmine::MenuManager.map(:top_menu).push(menu_name, item[:url], menu_options)
  end

  def additionals_custom_top_menu_item(num, user_roles)
    menu_name = 'custom_menu' + num.to_s
    item = {
      url: Additionals.settings[menu_name + '_url'],
      name: Additionals.settings[menu_name + '_name'],
      title: Additionals.settings[menu_name + '_title'],
      roles: Additionals.settings[menu_name + '_roles']
    }
    if item[:name].blank? || item[:url].blank? || item[:roles].nil?
      Redmine::MenuManager.map(:top_menu).delete(menu_name.to_sym) if Redmine::MenuManager.map(:top_menu).exists?(menu_name.to_sym)
      return
    end

    show_entry = false
    item[:roles].each do |role|
      if user_roles.empty? && role.to_i == Role::BUILTIN_ANONYMOUS
        show_entry = true
        break
      elsif User.current.logged? && role.to_i == Role::BUILTIN_NON_MEMBER
        # if user is logged in and non_member is active in item,
        # always show it
        show_entry = true
        break
      end

      user_roles.each do |user_role|
        if role.to_i == user_role.id.to_i
          show_entry = true
          break
        end
      end
      break if show_entry == true
    end

    if show_entry
      handle_top_menu_item(menu_name, item)
    elsif Redmine::MenuManager.map(:top_menu).exists?(menu_name.to_sym)
      Redmine::MenuManager.map(:top_menu).delete(menu_name.to_sym)
    end
  end

  def addtionals_help_plugin_items
    user_items = [{ title: 'Redmine Guide', url: Redmine::Info.help_url },
                  { title: "Redmine #{l(:label_macro_plural)}", url: macros_path }]

    admin_items = [{ title: 'Additionals', url: 'https://additionals.readthedocs.io/en/latest/manual/', manual: true },
                   { title: 'Redmine Changelog', url: 'https://www.redmine.org/projects/redmine/wiki/Changelog_3_4' },
                   { title: 'Redmine Upgrade', url: 'https://www.redmine.org/projects/redmine/wiki/RedmineUpgrade' },
                   { title: 'Redmine Security Advisories', url: 'https://www.redmine.org/projects/redmine/wiki/Security_Advisories' }]

    Redmine::Plugin.all.each do |plugin|
      next if plugin.id == :additionals

      begin
        plugin_item = plugin.id.to_s.camelize.constantize.try(:additionals_help_items)
        plugin_item = additionals_help_items_fallbacks(plugin.id) if plugin_item.nil?
        unless plugin_item.nil?
          plugin_item.each do |temp_item|
            user_items << if !temp_item[:manual].nil? && temp_item[:manual]
                            { title: "#{temp_item[:title]} #{l(:label_help_manual)}", url: temp_item[:url] }
                          else
                            { title: temp_item[:title], url: temp_item[:url] }
                          end
          end
        end
      rescue StandardError => e
        raise e unless e.class.to_s == 'NameError'
      end

      next unless User.current.admin?

      begin
        plugin_item = plugin.id.to_s.camelize.constantize.try(:additionals_help_admin_items)
        plugin_item = additionals_help_admin_items_fallbacks(plugin.id) if plugin_item.nil?
        admin_items += plugin_item unless plugin_item.nil?
      rescue StandardError => e
        raise e unless e.class.to_s == 'NameError'
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
             content_tag(:li, tag(:hr))
           else
             html_options = { class: 'help_item_' + idx.to_s }
             if item[:url].include? '://'
               html_options[:class] << ' external'
               html_options[:target] = '_blank'
             end
             content_tag(:li,
                         link_to(item[:title], item[:url], html_options))
           end
    end
    safe_join(s)
  end

  # Plugin help items definition for plugins,
  # which do not have additionals_help_menu_items integration
  def additionals_help_items_fallbacks(plugin_id)
    plugins = { redmine_wiki_lists: [{ title: 'Wiki Lists Marcos',
                                       url: 'https://www.r-labs.org/projects/wiki_lists/wiki/Wiki_Lists_en' }],
                redmine_wiki_extensions: [{ title: 'Wiki Extensions',
                                            url: 'https://www.r-labs.org/projects/r-labs/wiki/Wiki_Extensions_en' }] }
    plugins[plugin_id]
  end

  # Plugin help items definition for plugins,
  # which do not have additionals_help_admin_menu_items integration
  def additionals_help_admin_items_fallbacks(plugin_id)
    plugins = { redmine_git_hosting: [{ title: 'Redmine Git Hosting',
                                        url: 'http://redmine-git-hosting.io/get_started/' }],
                redmine_contacts: [{ title: 'Redmine CRM',
                                     url: 'https://www.redmineup.com/pages/help/crm' }],
                redmine_contacts_helpdesk: [{ title: 'Redmine Helpdesk',
                                              url: 'https://www.redmineup.com/pages/help/helpdesk' }],
                redmine_ldap_sync: [{ title: 'Redmine LDAP',
                                      url: 'https://www.redmine.org/projects/redmine/wiki/RedmineLDAP' },
                                    { title: 'Redmine LDAP Sync',
                                      url: 'https://github.com/thorin/redmine_ldap_sync/blob/master/README.md' }] }
    plugins[plugin_id]
  end
end
