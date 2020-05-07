module Additionals
  module Helpers
    def additionals_list_title(options)
      title = []
      if options[:issue]
        title << link_to(h("#{options[:issue].subject} ##{options[:issue].id}"),
                         issue_path(options[:issue]),
                         class: options[:issue].css_classes)
      elsif options[:user]
        title << avatar(options[:user], size: 50) + ' ' + options[:user].name
      end
      title << options[:name] if options[:name]
      title << h(options[:query].name) if options[:query] && !options[:query].new_record?
      safe_join(title, Additionals::LIST_SEPARATOR)
    end

    def additionals_title_for_locale(title, lang)
      "#{title}_#{lang}"
    end

    def additionals_titles_for_locale(title)
      languages = [title.to_sym]
      valid_languages.each do |lang|
        languages << additionals_title_for_locale(title, lang).to_sym if lang.to_s.exclude? '-'
      end
      languages
    end

    def additionals_i18n_title(options, title)
      i18n_title = "#{title}_#{::I18n.locale}".to_sym
      if options.key?(i18n_title)
        options[i18n_title]
      elsif options.key?(title)
        options[title]
      end
    end

    def render_issue_macro_link(issue, text, comment_id = nil)
      only_path = controller_path.split('_').last != 'mailer'
      content = link_to(text, issue_url(issue, only_path: only_path), class: issue.css_classes)
      if comment_id.nil?
        content
      else
        render_issue_with_comment(issue, content, comment_id, only_path)
      end
    end

    def render_issue_with_comment(issue, content, comment_id, only_path = false)
      journal = issue.journals.select(:notes, :private_notes, :user_id).offset(comment_id - 1).limit(1).first
      comment = if journal
                  user = User.current
                  if user.allowed_to?(:view_private_notes, issue.project) ||
                     !journal.private_notes? ||
                     journal.user == user
                    journal.notes
                  end
                end

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

    def memberships_new_issue_project_url(user, memberships, permission = :edit_issues)
      return if memberships.blank?

      project_count = 0
      project_id = nil
      memberships.each do |m|
        project = m.is_a?(Project) ? m : Project.find_by(id: m.project_id)
        next unless User.current.allowed_to?(permission, project) && user.issues_assignable?(project)

        project_count += 1
        break if project_count > 1

        project_id = project.identifier
      end

      return if project_id.nil?

      # if more than one projects available, we do not use project url for a new issue
      if project_count > 1
        if permission == :edit_issues
          new_issue_path('issue[assigned_to_id]' => user.id, 'issue[project_id]' => project_id)
        else
          new_issue_path('issue[project_id]' => project_id)
        end
      elsif permission == :edit_issues
        new_project_issue_path(project_id, 'issue[assigned_to_id]' => user.id)
      else
        new_project_issue_path(project_id)
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
        if request.nil?
          # this is used by mailer
          return rc if url.exclude?(Setting.host_name)
        elsif uri.host != URI.parse(request.original_url).host
          return rc
        end

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
        if secs.positive?
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
        # this should be mac os
        seconds = `sysctl -n kern.boottime | awk '{print $4}'`.tr(',', '')
        so = DateTime.strptime(seconds.strip, '%s')
        if so.present?
          time_tag(so)
        else
          days = `uptime | awk '{print $3}'`.to_i.round
          "#{days} #{l(:days, count: days)}"
        end
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
      true if /cygwin|mswin|mingw|bccwin|wince|emx/.match?(RUBY_PLATFORM)
    end

    def autocomplete_select_entries(name, type, option_tags, options = {})
      unless option_tags.is_a?(String) || option_tags.blank?
        # if option_tags is not an array, it should be an object
        option_tags = options_for_select([[option_tags.try(:name), option_tags.try(:id)]], option_tags.try(:id))
      end
      options[:project] = @project if @project && options[:project].blank?

      s = []
      s << hidden_field_tag("#{name}[]", '') if options[:multiple]
      s << select_tag(name,
                      option_tags,
                      include_blank: options[:include_blank],
                      multiple: options[:multiple],
                      disabled: options[:disabled])
      s << render(layout: false,
                  partial: 'additionals/select2_ajax_call.js',
                  formats: [:js],
                  locals: { field_id: sanitize_to_id(name),
                            ajax_url: send("#{type}_path", project_id: options[:project], user_id: options[:user_id]),
                            options: options })
      safe_join(s)
    end

    def project_list_css_classes(project, level)
      classes = [cycle('odd', 'even')]
      classes += project.css_classes.split(' ')
      if level.positive?
        classes << 'idnt'
        classes << "idnt-#{level}"
      end
      classes.join(' ')
    end

    def options_with_custom_fields(type, format, current, options = {})
      klass = Object.const_get("#{type}CustomField")
      fields = []
      fields << ["- #{l(:label_disabled)} -", 0] if options[:include_disabled]
      klass.sorted.each do |field|
        fields << [field.name, field.id] if Array(format).include?(field.field_format)
      end

      options_for_select(fields, current)
    end

    def addtionals_textarea_cols(text, options = {})
      [[(options[:min].presence || 8), text.to_s.length / 50].max, (options[:max].presence || 20)].min
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
      additionals_include_css('select2') +
        additionals_include_js('select2.min') +
        additionals_include_js('select2_helper')
    end

    def additionals_load_clipboardjs
      additionals_include_js('clipboard.min')
    end

    def additionals_load_observe_field
      additionals_include_js('additionals_observe_field')
    end

    def additionals_load_font_awesome
      additionals_include_css('fontawesome-all.min')
    end

    def additionals_load_chartjs
      additionals_include_css('Chart.min') +
        additionals_include_js('Chart.bundle.min')
    end

    def additionals_load_chartjs_datalabels
      additionals_include_js('chartjs-plugin-datalabels.min')
    end

    def additionals_load_chartjs_colorschemes
      additionals_include_js('chartjs-plugin-colorschemes.min')
    end

    def additionals_load_mermaid
      additionals_include_js('mermaid.min') +
        additionals_include_js('mermaid_load')
    end

    def additionals_load_d3
      additionals_include_js('d3.min')
    end

    def additionals_load_d3plus
      additionals_include_js('d3plus.full.min')
    end

    def user_with_avatar(user, options = {})
      return if user.nil?

      if user.type == 'Group'
        if options[:no_link]
          user.name
        elsif Redmine::Plugin.installed?('redmine_hrm')
          link_to_hrm_group(user)
        else
          user.name
        end
      else
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

    # if project exists, for project/show
    # if project does not exist, for welcome/index
    def option_of_overview_select(selected, project = nil)
      project.present? && %w[project always].include?(selected) ||
        project.nil? && %w[home always].include?(selected)
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
