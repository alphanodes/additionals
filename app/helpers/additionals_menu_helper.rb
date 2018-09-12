module AdditionalsMenuHelper
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

  def additionals_help_menu_items
    pages = [{ title: 'Redmine Guide', url: Redmine::Info.help_url },
             { title: 'FontAwesome Icons', url: 'https://fontawesome.com/icons?d=gallery&m=free' },
             { title: 'Redmine macros', url: macros_path }]

    if User.current.admin?
      pages << { title: '-' }
      pages << { title: 'Additionals manual', url: 'https://additionals.readthedocs.io/en/latest/manual/' }
      pages << { title: 'Redmine Changelog', url: 'https://www.redmine.org/projects/redmine/wiki/Changelog_3_4' }
      pages << { title: 'Redmine Upgrade', url: 'https://www.redmine.org/projects/redmine/wiki/RedmineUpgrade' }
      pages << { title: 'Redmine Security Advisories', url: 'https://www.redmine.org/projects/redmine/wiki/Security_Advisories' }
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
end
