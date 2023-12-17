# frozen_string_literal: true

module Additionals
  module GlobalTestHelper
    def after_setup
      return super unless defined?(Bullet) && Bullet.enable?

      Bullet.unused_eager_loading_enable = false
      Bullet.raise = true
      # @see https://github.com/flyerhzm/bullet#safe-list
      # ignore missing n+1 problems in redmine core
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Attachment', association: :author
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Attachment', association: :container
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Board', association: :messages
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Dashboard', association: :author
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Dashboard', association: :dashboard_roles
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Dashboard', association: :project
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Issue', association: :assigned_to
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Issue', association: :category
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Issue', association: :custom_values
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Issue', association: :fixed_version
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Issue', association: :parent
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Issue', association: :tracker
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Journal', association: :details
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Journal', association: :journal_message
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Journal', association: :journalized
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Member', association: :member_roles
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Member', association: :project
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Message', association: :attachments
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Message', association: :children
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Message', association: :parent
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'News', association: :attachments
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :attachments
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :boards
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :contacts
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :dashboards
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :db_entries
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :documents
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :helpdesk_setting
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :invoice_setting
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :invoices
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :issues
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :messenger_setting
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :news
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :parent
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :passwords
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :repositories
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :tag_taggings
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :taggings
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :time_entries
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :versions
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Project', association: :wiki
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'TimeEntry', association: :automation_schedule
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'TimeEntry', association: :reporting_cost
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Tracker', association: :default_status
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'User', association: :local_avatar
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'User', association: :preference
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'Version', association: :attachments
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'WikiContent', association: :page
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'WikiPage', association: :attachments
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'WikiPage', association: :content
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'WikiPage', association: :links_from
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'WikiPage', association: :tag_taggings
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'WikiPage', association: :taggings
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'WikiPage', association: :wiki
      Bullet.add_safelist type: :n_plus_one_query, class_name: 'WikiPage', association: :wiki_page_votes
      Bullet.start_request
      super
    end

    def before_teardown
      super
      return unless defined?(Bullet) && Bullet.enable?

      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
      Bullet.raise = false
    end

    def assert_select_td_column(column_name, colspan: nil)
      c = column_name.to_s
                     .gsub('issue.cf', 'issue_cf')
                     .gsub('project.cf', 'project_cf')
                     .gsub('user.cf', 'user_cf')
                     .tr('.', '-')

      spec = +"td.#{c}"
      spec << "[colspan='#{colspan}']" if colspan

      assert_select spec
    end

    def assert_select_totalable_columns(columns)
      assert_select 'p.query-totals' do
        columns.each do |column_name|
          c = column_name.to_s
                         .tr('_', '-')

          assert_select ".total-for-#{c} span.value"
        end
      end
    end

    def assert_select_grouped_column(column_name)
      assert_select 'tr.group.open', {}, "grouped_by with #{column_name} is missing tr.group.open"
    end

    def assert_select_query_tr(inline_columns:, block_columns:, inline_tr_select:, block_tr_select:, with_checkbox: true)
      assert_select inline_tr_select do
        inline_columns.each do |column_name|
          assert_select_td_column column_name
        end
      end

      colspan = inline_columns.count + 2
      colspan -= 1 unless with_checkbox
      assert_select block_tr_select do
        block_columns.each do |column_name|
          assert_select_td_column column_name, colspan: colspan
        end
      end
    end

    def with_plugin_settings(plugin, settings, &_block)
      change_plugin_settings plugin, settings
      yield
    ensure
      restore_plugin_settings plugin
    end

    def change_plugin_settings(plugin, settings)
      instance_variable_set :"@saved_#{plugin}_settings", Setting.send(:"plugin_#{plugin}").dup
      new_settings = Setting.send(:"plugin_#{plugin}").dup
      settings.each do |key, value|
        new_settings[key] = value
      end

      Setting.send :"plugin_#{plugin}=", new_settings
    end

    def restore_plugin_settings(plugin)
      settings = instance_variable_get :"@saved_#{plugin}_settings"
      if settings
        Setting.send :"plugin_#{plugin}=", settings
      else
        Rails.logger.warn "warning: restore_plugin_settings could not restore settings for #{plugin}"
      end
    end

    def assert_sorted_equal(list1, list2, comment = nil)
      assert_equal list1.sort, list2.sort, comment
    end

    def assert_query_sort_order(table_css, column, action: nil, list_columns: [], params: {})
      action = :index if action.blank?
      column = column.to_s
      column_css = column.tr('_', '-').gsub('.', '\.')
      columns = (list_columns << column).uniq

      params[:sort] = "#{column}:asc"
      params[:c] = columns

      get action, params: params

      assert_response :success
      assert_select "table.list.#{table_css}.sort-by-#{column_css}.sort-asc"

      params[:sort] = "#{column}:desc"

      get action, params: params

      assert_response :success
      assert_select "table.list.#{table_css}.sort-by-#{column_css}.sort-desc"
    end

    def assert_dashboard_query_blocks(blocks = [])
      blocks.each do |block_def|
        block_def[:user_id]
        @request.session[:user_id] = block_def[:user_id].presence || 2
        get block_def[:action].presence || :show,
            params: { dashboard_id: block_def[:dashboard_id],
                      block: block_def[:block],
                      project_id: block_def[:project],
                      format: 'js' }

        assert_response :success, "assert_response for #{block_def[:block]}"
        assert_select "table.list.#{block_def[:entities_class]}"
      end
    end

    # Return the columns that are displayed in the list
    def columns_in_projects_list
      css_select('table.projects thead th').map(&:text)
    end

    # should be dropped after dropping Rails 6.x support / Redmine 5.1 support
    def self.fixture_date_format(date)
      date.try(:to_fs, :db) || date.to_s(:db)
    end
  end
end
