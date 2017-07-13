# Redmine hooks
module Additionals
  class AdditionalsHookListener < Redmine::Hook::ViewListener
    render_on(:view_layouts_base_html_head, partial: 'additionals/html_head')
    render_on(:view_layouts_base_content, partial: 'additionals/content')
    render_on(:view_layouts_base_body_bottom, partial: 'additionals/body_bottom')

    render_on(:view_account_login_bottom, partial: 'login_text')
    render_on(:view_welcome_index_right, partial: 'overview_right')
    render_on(:view_issues_new_top, partial: 'new_ticket_message')
    render_on(:view_issues_sidebar_queries_bottom, partial: 'additionals/global_sidebar')
    render_on(:view_projects_show_right, partial: 'project_overview')
    render_on(:view_projects_show_sidebar_bottom, partial: 'additionals/global_sidebar')

    def controller_issues_new_before_save(context)
      issue_auto_assign(context)
    end

    def controller_issues_edit_before_save(context)
      issue_auto_assign(context)
    end

    def issue_auto_assign(context)
      return if Additionals.settings[:issue_auto_assign].blank? ||
                Additionals.settings[:issue_auto_assign_status].blank? ||
                Additionals.settings[:issue_auto_assign_role].blank?
      if context[:params][:issue][:assigned_to_id].blank? &&
         Additionals.settings[:issue_auto_assign_status].include?(context[:params][:issue][:status_id].to_s)
        context[:issue].assigned_to_id = context[:issue].auto_assign_user
      end
    end
  end
end
