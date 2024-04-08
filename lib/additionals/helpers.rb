# frozen_string_literal: true

module Additionals
  module Helpers
    def label_with_count(label, info, only_positive: false)
      text = label.is_a?(Symbol) ? l(label) : label
      if info.blank? || only_positive && !info.positive?
        text
      else
        safe_join [text, ' (', info, ')']
      end
    end

    def render_query_group_view(query, locals = {})
      return if locals[:group_name].blank?

      render partial: 'queries/additionals_group_view',
             locals: { query: query }.merge(locals)
    end

    def render_query_block_columns(query, entry, tr_classes:, with_buttons: false, with_checkbox: true)
      td_colspan = query.inline_columns.size + 1
      td_colspan += 1 if with_buttons

      content = []
      query.block_columns.each do |column|
        next if !(text = column_content column, entry) || text.blank?

        content << tag.tr(class: "#{tr_classes} block-row") do
          tds = []
          tds << tag.td('', class: 'hide') if with_buttons && with_checkbox
          tds << tag.td(colspan: td_colspan, class: "#{column.css_classes} block_column") do
            td_content = []
            td_content << tag.span(column.caption) if query.block_columns.count > 1
            td_content << text
            safe_join td_content
          end

          safe_join tds
        end
      end

      safe_join content
    end

    def render_query_description(query)
      return unless query.description? && query.persisted?

      tag.div textilizable(query, :description), class: 'query-description'
    end

    def live_search_title_info(entity)
      fields = "LiveSearch::#{entity.to_s.classify}".constantize.info_fields
      all_fields = fields.map { |f| "#{f}:term" }.to_comma_list
      l :label_live_search_hints, value: all_fields
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
      i18n_title = :"#{title}_#{::I18n.locale}"
      if options.key? i18n_title
        options[i18n_title]
      elsif options.key? title
        options[title]
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

      return unless project_id

      # if more than one projects available, we do not use project url for a new issue
      if project_count > 1
        if permission == :edit_issues
          new_issue_path 'issue[assigned_to_id]' => user.id, 'issue[project_id]' => project_id
        else
          new_issue_path 'issue[project_id]' => project_id
        end
      elsif permission == :edit_issues
        new_project_issue_path project_id, 'issue[assigned_to_id]' => user.id
      else
        new_project_issue_path project_id
      end
    end

    def additionals_library_load(module_names)
      safe_join(Array(module_names).map { |module_name| send(:"additionals_load_#{module_name}") })
    end

    def autocomplete_select_entries(name, type, option_tags, **options)
      if option_tags.present?
        if option_tags.is_a? ActiveRecord::Relation
          option_tags = options_for_select option_tags.map { |u| [u.name, u.id] }, option_tags.map(&:id)
        elsif !option_tags.is_a?(String)
          # if option_tags is not an array, it should be an object
          option_tags = options_for_select [[option_tags.try(:name), option_tags.try(:id)]], option_tags.try(:id)
        end
      else
        # NOTE: without data select_tag raise error if include_blank is used,
        # e.g. ActionView::Template::Error (no implicit conversion of DbEntry::ActiveRecord_Relation into String)
        option_tags = ''
      end

      ajax_params = options.delete(:ajax_params) || {}
      if options[:project].present?
        ajax_params[:project_id] = options[:project]
      elsif @project
        ajax_params[:project_id] = @project
      end

      s = []
      s << hidden_field_tag("#{name}[]", '') if options[:multiple]
      s << select_tag(name,
                      option_tags,
                      include_blank: options[:include_blank],
                      multiple: options[:multiple],
                      disabled: options[:disabled])
      s << render(layout: false,
                  partial: 'additionals/select2_ajax_call',
                  formats: [:js],
                  locals: { field_name_id: sanitize_to_id(name),
                            ajax_url: send(:"#{type}_path", ajax_params),
                            options: options })
      safe_join s
    end

    def project_list_css_classes(project, level)
      classes = [cycle('odd', 'even')]
      classes += project.css_classes.split
      if level.positive?
        classes << 'idnt'
        classes << "idnt-#{level}"
      end
      classes.join ' '
    end

    def addtionals_textarea_cols(text, min: 8, max: 20)
      RedminePluginKit.textarea_cols text, min: min, max: max
    end

    def title_with_fontawesome(title, symbole, wrapper = 'span')
      tag.send wrapper do
        concat tag.i class: "#{symbole} for-fa-title", 'aria-hidden': 'true'
        concat title
      end
    end

    def format_yes(value, lowercase: false)
      if RedminePluginKit.true? value
        lowercase ? l(:general_text_yes) : l(:general_text_Yes)
      else
        lowercase ? l(:general_text_no) : l(:general_text_No)
      end
    end

    def user_with_avatar(user, no_link: false, css_class: 'additionals-avatar', size: 14, no_link_name: nil)
      return unless user

      if user.type == 'Group'
        if no_link || !AdditionalsPlugin.active_hrm?
          user.name
        else
          link_to_hrm_group user
        end
      else
        s = []
        s << avatar(user, size: size, class: css_class)
        s << if no_link
               no_link_name || user.name
             else
               link_to_user user
             end
        safe_join s
      end
    end

    def options_for_menu_select(active)
      options_for_select({ l(:button_hide) => '',
                           l(:label_top_menu) => 'top',
                           l(:label_app_menu) => 'app' }, active)
    end

    def human_float_number(value, precision: 2, separator: '.')
      ActionController::Base.helpers.number_with_precision(value,
                                                           precision: precision,
                                                           separator: separator,
                                                           strip_insignificant_zeros: true)
    end

    def query_list_back_url_tag(project = nil, params = nil)
      url = if controller_name == 'dashboard_async_blocks' && request.query_parameters.key?('dashboard_id')
              dashboard_link_path project,
                                  Dashboard.find_by(id: request.query_parameters['dashboard_id']),
                                  refresh: 1
            elsif params.nil?
              url_for params: request.query_parameters
            else
              url_for params: params
            end

      hidden_field_tag 'back_url', url, id: nil
    end

    def render_author_line(entry, created_field: :created_on, updated_field: :updated_on)
      created = entry.send created_field
      updated = entry.send updated_field
      tag.p class: 'author' do
        str = [authoring(created, entry.author)]
        str << '.'
        if created != updated
          str << ' '
          str << l(:label_updated_time, time_tag(updated)).html_safe
          str << '.'
        end
        safe_join str
      end
    end

    def render_label_sum(label, sum)
      name = label.is_a?(Symbol) ? l(label) : label
      "#{name} (#{sum})"
    end

    private

    def additionals_already_loaded(scope, js_name)
      locked = "#{js_name}.#{scope}"
      @alreaded_loaded = [] if @alreaded_loaded.nil?
      return true if @alreaded_loaded.include? locked

      @alreaded_loaded << locked
      false
    end

    def additionals_include_js(js_name, core: false)
      if additionals_already_loaded 'js', js_name
        ''
      else
        javascript_include_tag js_name, plugin: core ? nil : 'additionals'
      end
    end

    def additionals_include_css(css)
      if additionals_already_loaded 'css', css
        ''
      else
        stylesheet_link_tag css, plugin: 'additionals'
      end
    end

    def additionals_load_select2
      additionals_include_css('select2') +
        additionals_include_js('select2.min') +
        additionals_include_js('select2_helpers')
    end

    def additionals_load_clipboardjs
      additionals_include_js 'clipboard.min'
    end

    def additionals_load_font_awesome
      additionals_include_css 'fontawesome-all.min'
    end

    def additionals_load_chartjs
      additionals_include_js 'chart.min', core: true
    end

    def additionals_load_chartjs_colorschemes
      additionals_include_js 'chartjs-plugin-colorschemes.min'
    end

    def additionals_load_chartjs_datalabels
      additionals_include_js 'chartjs-plugin-datalabels.min'
    end

    def additionals_load_chartjs_annotation
      additionals_include_js 'chartjs-plugin-annotation.min'
    end

    def additionals_load_chartjs_moment
      additionals_include_js('moment-with-locales.min') +
        additionals_include_js('chartjs-adapter-moment.min')
    end

    def additionals_load_chartjs_matrix
      additionals_load_chartjs_moment +
        additionals_include_js('chartjs-chart-matrix.min')
    end

    def additionals_load_mermaid
      additionals_include_js('mermaid.min') +
        additionals_include_js('mermaid_load')
    end

    def additionals_load_d3
      additionals_include_js 'd3.min'
    end

    def additionals_load_d3plus
      additionals_include_js 'd3plus.min'
    end
  end
end
