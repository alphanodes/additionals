# Redmine hooks
module Additionals
  class AdditionalsHookListener < Redmine::Hook::ViewListener
    include IssuesHelper
    include AdditionalsIssuesHelper

    render_on(:view_layouts_base_html_head, partial: 'additionals/html_head')
    render_on(:view_layouts_base_content, partial: 'additionals/content')
    render_on(:view_layouts_base_body_bottom, partial: 'additionals/body_bottom')

    render_on(:view_account_login_bottom, partial: 'login_text')
    render_on(:view_issues_bulk_edit_details_bottom, partial: 'change_author_bulk')
    render_on(:view_issues_form_details_bottom, partial: 'change_author')
    render_on(:view_issues_new_top, partial: 'new_ticket_message')
    render_on(:view_issues_sidebar_queries_bottom, partial: 'additionals/global_sidebar')
    render_on(:view_projects_show_right, partial: 'project_overview')
    render_on(:view_projects_show_sidebar_bottom, partial: 'additionals/global_sidebar')
    render_on(:view_welcome_index_right, partial: 'overview_right')
    render_on(:view_my_account_preferences, partial: 'users/autowatch_involved_issue')
    render_on(:view_users_form_preferences, partial: 'users/autowatch_involved_issue')

    def helper_issues_show_detail_after_setting(context = {})
      d = context[:detail]
      return unless d.prop_key == 'author_id'

      d[:value] = find_name_by_reflection('author', d.value)
      d[:old_value] = find_name_by_reflection('author', d.old_value)
    end

    def controller_issues_new_before_save(context = {})
      issue_auto_assign(context)
    end

    def controller_issues_edit_before_save(context = {})
      issue_auto_assign(context)
    end
  end
end
