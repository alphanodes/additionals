# Global helper functions
module Additionals
  module Helpers
    def additionals_settings_tabs
      tabs = []
      tabs << { name: 'general', partial: 'additionals/settings/general', label: :label_general }
      tabs << { name: 'content', partial: 'additionals/settings/overview', label: :label_overview_page }
      tabs << { name: 'wiki', partial: 'additionals/settings/wiki', label: :label_wiki }
      tabs << { name: 'rules', partial: 'additionals/settings/issues', label: :label_issue_plural }
      tabs << { name: 'projects', partial: 'additionals/settings/projects', label: :label_project_plural }
      if User.current.try(:hrm_user_manager).nil?
        tabs << { name: 'menu', partial: 'additionals/settings/menu', label: :label_settings_menu }
      end
      tabs << { name: 'macros', partial: 'additionals/settings/macros', label: :label_settings_macros }

      tabs
    end

    def additionals_library_load(module_name)
      method = "additionals_load_#{module_name}"
      send(method)
    end

    def system_uptime
      if windows_platform?
        `net stats srv | find "Statist"`
      elsif File.exist?('/proc/uptime')
        secs = `cat /proc/uptime`.to_i
        min = 0
        hours = 0
        days = 0
        if secs > 0
          min = (secs / 60).round
          hours = (secs / 3_600).round
          days = (secs / 86_400).round
        end
        if days >= 1
          "#{days} #{l(:days, count: days)}"
        elsif hours >= 1
          "#{hours} #{l(:hours, count: hours)}"
        else
          "#{min} #{l(:minutes, count: min)}"
        end
      else
        days = `uptime | awk '{print $3}'`.to_i.round
        "#{days} #{l(:days, count: days)}"
      end
    end

    def system_info
      if windows_platform?
        'unknown'
      else
        `uname -a`
      end
    end

    def windows_platform?
      true if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
    end

    def memberbox_view_roles
      view_roles = []
      @users_by_role.keys.sort.each do |role|
        if !role.permissions.include?(:hide_in_memberbox) ||
           (role.permissions.include?(:hide_in_memberbox) && User.current.allowed_to?(:show_hidden_roles_in_memberbox, @project))
          view_roles << role
        end
      end
      view_roles
    end

    def additionals_custom_top_menu_item(i, user_roles)
      menu_name = 'custom_menu' + i.to_s
      item = {
        url: Additionals.settings[menu_name + '_url'],
        name: Additionals.settings[menu_name + '_name'],
        title: Additionals.settings[menu_name + '_title'],
        roles: Additionals.settings[menu_name + '_roles']
      }
      if item[:name].blank? || item[:url].blank? || item[:roles].nil?
        if Redmine::MenuManager.map(:top_menu).exists?(menu_name.to_sym)
          Redmine::MenuManager.map(:top_menu).delete(menu_name.to_sym)
        end
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

    def handle_top_menu_item(menu_name, item)
      if Redmine::MenuManager.map(:top_menu).exists?(menu_name.to_sym)
        Redmine::MenuManager.map(:top_menu).delete(menu_name.to_sym)
      end

      html_options = {}
      html_options[:class] = 'external' if item[:url].include? '://'
      html_options[:title] = item[:title] if item[:title].present?

      title = if item[:symbol].present? && item[:name].present?
                fa_icon(item[:symbol], post_text: item[:name])
              elsif item[:symbol].present?
                fa_icon(item[:symbol])
              else
                item[:name].to_s
              end

      Redmine::MenuManager.map(:top_menu).push menu_name,
                                               item[:url],
                                               parent: item[:parent].present? ? item[:parent].to_sym : nil,
                                               caption: title,
                                               html: html_options,
                                               before: :help
    end

    def bootstrap_datepicker_locale
      s = ''
      locale = User.current.language.blank? ? ::I18n.locale : User.current.language
      s = javascript_include_tag("locales/bootstrap-datepicker.#{locale}.min", plugin: 'additionals') unless locale == 'en'
      s
    end

    private

    def additionals_already_loaded(scope, js)
      locked = "#{js}.#{scope}"
      @alreaded_loaded = [] if @alreaded_loaded.nil?
      return true if @alreaded_loaded.include?(locked)
      @alreaded_loaded << locked
      false
    end

    def additionals_include_js(js)
      if additionals_already_loaded('js', js)
        ''
      else
        javascript_include_tag(js, plugin: 'additionals') + "\n"
      end
    end

    def additionals_include_css(css)
      if additionals_already_loaded('css', css)
        ''
      else
        stylesheet_link_tag(css, plugin: 'additionals') + "\n"
      end
    end

    def additionals_load_font_awesome
      additionals_include_css('font-awesome.min')
    end

    def additionals_load_angular_gantt
      additionals_include_css('angular-gantt.min') +
        additionals_include_css('angular-gantt-plugins.min') +
        additionals_include_css('angular-ui-tree.min') +
        additionals_include_js('moment-with-locales.min') +
        additionals_include_js('angular.min') +
        additionals_include_js('angular-moment.min') +
        additionals_include_js('angular-ui-tree.min') +
        additionals_include_js('angular-gantt.min') +
        additionals_include_js('angular-gantt-plugins.min')
    end

    def additionals_load_nvd3
      additionals_include_css('nv.d3.min') +
        additionals_include_js('d3.min') +
        additionals_include_js('nv.d3.min')
    end

    def additionals_load_d3plus
      additionals_include_js('d3.min') +
        additionals_include_js('d3plus.min')
    end

    def additionals_load_tooltips
      additionals_include_css('tooltips') +
        additionals_include_js('tooltips')
    end

    def additionals_load_bootstrap
      additionals_include_css('bootstrap.min') +
        additionals_include_js('bootstrap.min')
    end

    def additionals_load_bootstrap_theme
      additionals_include_css('bootstrap.min') +
        additionals_include_css('bootstrap-theme.min') +
        additionals_include_js('bootstrap.min')
    end

    def additionals_load_tag_it
      additionals_include_css('jquery.tagit') +
        additionals_include_js('tag-it')
    end

    def additionals_load_zeroclipboard
      additionals_include_js('zeroclipboard_min')
    end

    def font_awesome_get_from_info
      s = []
      s << l(:label_set_icon_from)
      s << link_to('http://fontawesome.io/icons/', 'http://fontawesome.io/icons/', class: 'external')
      safe_join(s, ' ')
    end

    def user_with_avatar(user, size = 14)
      return if user.nil?
      s = []
      s << avatar(user, size: size)
      s << link_to_user(user)
      safe_join(s)
    end

    def fa_icon(name, options = {})
      post_text = ''
      classes = ['fa']
      classes << name

      options['aria-hidden'] = 'true'
      options[:class] = if options[:class].present?
                          classes.join(' ') + ' ' + options[:class]
                        else
                          classes.join(' ')
                        end

      s = []
      if options[:pre_text].present?
        s << options[:pre_text]
        s << ' '
        options.delete(:pre_text)
      end
      if options[:post_text].present?
        post_text = options[:post_text]
        options.delete(:post_text)
      end
      s << content_tag('span', '', options)
      if post_text.present?
        s << ' '
        s << post_text
      end
      safe_join(s)
    end

    def query_default_sort(query, fall_back_sort)
      criteria = query.sort_criteria.any? ? query.sort_criteria : fall_back_sort
      return unless criteria.is_a?(Array)
      sql = []
      criteria.each do |sort|
        name = sort[0]
        field = []
        field << query.queried_class.table_name if name == 'name'
        field << name
        sql << "#{field.join('.')} #{sort[1].upcase}"
      end
      sql.join(', ')
    end

    def options_for_overview_select(active)
      options_for_select({ l(:button_hide) => '',
                           l(:show_on_redmine_home) => 'home',
                           l(:show_on_project_overview) => 'project',
                           l(:show_always) => 'always' }, active)
    end

    def options_for_welcome_select(active)
      options_for_select({ l(:button_hide) => '',
                           l(:show_welcome_left) => 'left',
                           l(:show_welcome_right) => 'right' }, active)
    end

    def human_float_number(value, sep = '.')
      ActionController::Base.helpers.number_with_precision(value,
                                                           precision: 2,
                                                           separator: sep,
                                                           strip_insignificant_zeros: true)
    end
  end
end

ActionView::Base.send :include, Additionals::Helpers
