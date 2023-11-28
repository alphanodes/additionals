# frozen_string_literal: true

module AdditionalsMenuHelper
  def additionals_top_menu_setup
    return if AdditionalsPlugin.active_hrm?

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

  def addtionals_help_plugin_items
    user_items = [{ title: 'Redmine Guide',
                    url: Redmine::Info.help_url,
                    id: :redmine_guide },
                  { title: "Redmine #{l :label_macro_plural}",
                    url: additionals_macros_path,
                    id: :macros }]

    admin_items = [{ title: 'Redmine Changelog',
                     url: "https://www.redmine.org/projects/redmine/wiki/Changelog_#{Redmine::VERSION::MAJOR}_#{Redmine::VERSION::MINOR}",
                     id: :changelog },
                   { title: 'Redmine Upgrade',
                     url: 'https://www.redmine.org/projects/redmine/wiki/RedmineUpgrade',
                     id: :redmine_upgrade },
                   { title: 'Redmine Security Advisories',
                     url: 'https://www.redmine.org/projects/redmine/wiki/Security_Advisories',
                     id: :security_advisories }]

    Redmine::Plugin.all.each do |plugin| # rubocop: disable Rails/FindEach
      next if plugin.id == :additionals

      plugin_item_base = nil

      begin
        plugin_item_base = plugin.id.to_s.camelize.constantize
      rescue LoadError
        Rails.logger.debug { "Ignore plugin #{plugin.id} for help integration" }
      rescue StandardError => e
        raise e unless e.instance_of? ::NameError
      end

      plugin_item = plugin_item_base.try :additionals_help_items unless plugin_item_base.nil?
      plugin_item = additionals_help_items_fallbacks plugin.id if plugin_item.nil?

      next if plugin_item.nil?

      plugin_item.each do |temp_item|
        title = Array temp_item[:title]
        title << l("label_help_#{temp_item[:type]}") if temp_item.key? :type
        u_items = { title: safe_join(title, ' '),
                    url: temp_item[:url],
                    id: temp_item[:id] }

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
      pages << { title: '-', id: :sep }
      pages += plugin_items[:admin].sort_by { |k| k[:title] }
    end

    s = []
    ids = []
    pages.each do |item|
      next unless item.key? :id

      id = item[:id]
      next if ids.include? id

      ids << id
      s << if item[:title] == '-'
             tag.li tag.hr
           else
             html_options = { class: +"help_item_#{id}" }
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
                                   id: :drawio,
                                   url: 'https://github.com/mikitex70/redmine_drawio#usage' }],
                redmine_agile: [{ title: 'Redmine Agile',
                                  id: :agile,
                                  url: 'https://www.redmineup.com/pages/help/agile' }],
                redmine_contacts: [{ title: 'Redmine CRM',
                                     id: :crm,
                                     url: 'https://www.redmineup.com/pages/help/crm',
                                     admin: true }],
                redmine_contacts_helpdesk: [{ title: 'Redmine Helpdesk',
                                              id: :helpdesk,
                                              url: 'https://www.redmineup.com/pages/help/helpdesk',
                                              admin: true }] }
    plugins[plugin_id]
  end
end
