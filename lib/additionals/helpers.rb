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
      tabs << { name: 'users', partial: 'additionals/settings/users', label: :label_user_plural }
      if User.current.try(:hrm_user_type_id).nil?
        tabs << { name: 'menu', partial: 'additionals/settings/menu', label: :label_settings_menu }
      end
      tabs << { name: 'web', partial: 'additionals/settings/web_apis', label: :label_web_apis }
      tabs << { name: 'macros', partial: 'additionals/settings/macros', label: :label_settings_macros }

      tabs
    end

    def render_issue_macro_link(issue, text, comment_id = nil)
      only_path = controller_path != 'mailer'
      content = link_to(text, issue_url(issue, only_path: only_path), class: issue.css_classes)
      if comment_id.nil?
        content
      else
        render_issue_with_comment(issue, content, comment_id, only_path)
      end
    end

    def render_issue_with_comment(issue, content, comment_id, only_path = false)
      comment = issue.journals
                     .where(private_notes: false)
                     .offset(comment_id - 1).limit(1).first.try(:notes)
      if comment.blank?
        comment = 'N/A'
        comment_link = comment_id
      else
        comment_link = link_to(comment_id, issue_url(issue, only_path: only_path, anchor: "note-#{comment_id}"))
      end

      content_tag :div, class: 'issue-macro box' do
        content_tag(:div, safe_join([content, '-', l(:label_comment), comment_link], ' '), class: 'issue-macro-subject') +
          content_tag(:div, textilizable(comment), class: 'issue-macro-comment journal has-notes')
      end
    end

    def memberships_new_issue_project_url(user, memberships)
      return if memberships.blank?
      project_count = 0
      project_id = nil
      memberships.each do |m|
        project = m.is_a?(Project) ? m : Project.find_by(id: m.project_id)
        next unless User.current.allowed_to?(:edit_issues, project) && user.allowed_to?(:edit_issues, project)
        project_count += 1
        break if project_count > 1
        project_id = project.identifier
      end

      return if project_id.nil?

      # if more than one projects available, we do not use project url for a new issue
      if project_count > 1
        new_issue_path('issue[assigned_to_id]' => user.id, 'issue[project_id]' => project_id)
      else
        new_project_issue_path(project_id, 'issue[assigned_to_id]' => user.id)
      end
    end

    def parse_issue_url(url, comment_id = nil)
      rc = { issue_id: nil, comment_id: nil }
      return rc if url == '' || url.is_a?(Integer) && url.zero?
      unless url.to_i.zero?
        rc[:issue_id] = url
        return rc
      end

      uri = URI.parse(url)
      # support issue_id plugin
      # see https://www.redmine.org/plugins/issue_id
      issue_id_parts = url.split('-')
      if uri.scheme.nil? && uri.path[0] != '/' && issue_id_parts.count == 2
        rc[:issue_id] = url
      else
        current_uri = URI.parse(request.original_url)
        return rc unless uri.host == current_uri.host
        s_pos = uri.path.rindex('/issues/')
        id_string = uri.path[s_pos + 8..-1]
        e_pos = id_string.index('/')
        rc[:issue_id] = e_pos.nil? ? id_string : id_string[0..e_pos - 1]
        # check for comment_id
        rc[:comment_id] = uri.fragment[5..-1].to_i if comment_id.nil? && uri.fragment.present? && uri.fragment[0..4] == 'note-'
      end

      rc
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

    def handle_top_menu_item(menu_name, item)
      Redmine::MenuManager.map(:top_menu).delete(menu_name.to_sym) if Redmine::MenuManager.map(:top_menu).exists?(menu_name.to_sym)

      html_options = {}
      html_options[:class] = 'external' if item[:url].include? '://'
      html_options[:title] = item[:title] if item[:title].present?

      title = if item[:symbol].present? && item[:name].present?
                font_awesome_icon(item[:symbol], post_text: item[:name])
              elsif item[:symbol].present?
                font_awesome_icon(item[:symbol])
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
      locale = User.current.language.presence || ::I18n.locale
      locale = 'es' if locale == 'es-PA'
      locale = 'sr-latin' if locale == 'sr-YU'
      s = javascript_include_tag("locales/bootstrap-datepicker.#{locale.downcase}.min", plugin: 'additionals') unless locale == 'en'
      s
    end

    def auto_complete_select_entries(name, type, option_tags, options = {})
      unless option_tags.is_a?(String) || option_tags.blank?
        # if option_tags is not an array, it should be an object
        option_tags = options_for_select([[option_tags.try(:name), option_tags.try(:id)]], option_tags.try(:id))
      end
      s = []
      s << hidden_field_tag("#{name}[]", '') if options[:multiple]
      s << select_tag(name,
                      option_tags,
                      include_blank: options[:include_blank],
                      multiple: options[:multiple],
                      disabled: options[:disabled], class: "#{type}-relation")
      s << render(layout: false,
                  partial: 'additionals/select2_ajax_call.js',
                  formats: [:js],
                  locals: { field_id: sanitize_to_id(name),
                            ajax_url: send("auto_complete_#{type}_path", project_id: @project, user_id: options[:user_id]),
                            options: options })
      safe_join(s)
    end

    private

    def additionals_already_loaded(scope, js_name)
      locked = "#{js_name}.#{scope}"
      @alreaded_loaded = [] if @alreaded_loaded.nil?
      return true if @alreaded_loaded.include?(locked)
      @alreaded_loaded << locked
      false
    end

    def additionals_include_js(js_name)
      if additionals_already_loaded('js', js_name)
        ''
      else
        javascript_include_tag(js_name, plugin: 'additionals') + "\n"
      end
    end

    def additionals_include_css(css)
      if additionals_already_loaded('css', css)
        ''
      else
        stylesheet_link_tag(css, plugin: 'additionals') + "\n"
      end
    end

    def additionals_load_select2
      additionals_include_js('additionals_to_select2')
    end

    def additionals_load_observe_field
      additionals_include_js('additionals_observe_field')
    end

    def additionals_load_delay_ajax_indicator
      additionals_include_js('additionals_delay_ajax_indicator')
    end

    def additionals_load_font_awesome
      additionals_include_css('fontawesome-all.min')
    end

    def additionals_load_nvd3
      additionals_include_css('nv.d3.min') +
        additionals_include_js('d3.min') +
        additionals_include_js('nv.d3.min')
    end

    def additionals_load_mermaid
      additionals_include_js('mermaid.min') +
        additionals_include_js('mermaid_load')
    end

    def additionals_load_d3plus
      additionals_include_js('d3.min') +
        additionals_include_js('d3plus.full.min')
    end

    def additionals_load_tag_it
      additionals_include_css('jquery.tagit') +
        additionals_include_js('tag-it')
    end

    def additionals_load_zeroclipboard
      additionals_include_js('zeroclipboard_min')
    end

    def user_with_avatar(user, options = {})
      return if user.nil?
      options[:size] = 14 if options[:size].nil?
      options[:class] = 'additionals-avatar' if options[:class].nil?
      s = []
      s << avatar(user, options)
      s << if options[:no_link]
             user.name
           else
             link_to_user(user)
           end
      safe_join(s)
    end

    def fontawesome_info_url
      s = []
      s << l(:label_set_icon_from)
      s << link_to('https://fontawesome.com/icons?m=free', 'https://fontawesome.com/icons?m=free', class: 'external')
      safe_join(s, ' ')
    end

    # name = TYPE-FA_NAME, eg. fas_car
    #                          fas_cloud-upload-alt
    #                          far_id-card
    #                          fab_font-awesome
    # options = class
    #           pre_text
    #           post_text
    #           title
    def font_awesome_icon(name, options = {})
      info = AdditionalsFontAwesome.value_info(name)
      return '' if info.blank?
      post_text = ''

      options['aria-hidden'] = 'true'
      options[:class] = if options[:class].present?
                          info[:classes] + ' ' + options[:class]
                        else
                          info[:classes]
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

    def options_for_menu_select(active)
      options_for_select({ l(:button_hide) => '',
                           l(:label_top_menu) => 'top',
                           l(:label_app_menu) => 'app' }, active)
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

    def human_float_number(value, options = {})
      ActionController::Base.helpers.number_with_precision(value,
                                                           precision: options[:precision].presence || 2,
                                                           separator: options[:separator].presence || '.',
                                                           strip_insignificant_zeros: true)
    end
  end
end

ActionView::Base.send :include, Additionals::Helpers
