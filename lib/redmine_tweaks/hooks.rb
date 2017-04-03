# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

module RedmineTweaks
  class RedmineTweaksHookListener < Redmine::Hook::ViewListener
    render_on(:view_layouts_base_html_head, partial: 'global_html_header')
    render_on(:view_layouts_base_content, partial: 'global_content')
    render_on(:view_layouts_base_body_bottom, partial: 'global_footer')

    render_on(:view_account_login_bottom, partial: 'login_text')
    render_on(:view_welcome_index_right, partial: 'overview_right')
    render_on(:view_issues_new_top, partial: 'new_ticket_message')
    render_on(:view_issues_sidebar_queries_bottom, partial: 'global_sidebar')
    render_on(:view_projects_show_right, partial: 'project_overview')
    render_on(:view_projects_show_sidebar_bottom, partial: 'global_sidebar')

    def controller_issues_new_before_save(context)
      issue_auto_assign(context)
    end

    def controller_issues_edit_before_save(context)
      issue_auto_assign(context)
    end

    def issue_auto_assign(context)
      return if RedmineTweaks.settings[:issue_auto_assign].blank? ||
                RedmineTweaks.settings[:issue_auto_assign_status].blank? ||
                RedmineTweaks.settings[:issue_auto_assign_role].blank?
      if context[:params][:issue][:assigned_to_id].blank? &&
         RedmineTweaks.settings[:issue_auto_assign_status].include?(context[:params][:issue][:status_id].to_s)
        context[:issue].assigned_to_id = context[:issue].auto_assign_user
      end
    end
  end

  def self.settings
    Setting[:plugin_redmine_tweaks]
  end
end
