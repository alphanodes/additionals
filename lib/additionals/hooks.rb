# frozen_string_literal: true

module Additionals
  class AdditionalsHookListener < Redmine::Hook::ViewListener
    include IssuesHelper
    include AdditionalsIssuesHelper

    render_on :view_layouts_base_html_head, partial: 'additionals/html_head'
    render_on :view_layouts_base_body_top, partial: 'additionals/body_top'
    render_on :view_layouts_base_body_bottom, partial: 'additionals/body_bottom'

    render_on :view_account_login_bottom, partial: 'login_text'
    render_on :view_issues_context_menu_start, partial: 'additionals_closed_issues'
    render_on :view_issues_bulk_edit_details_bottom, partial: 'change_author_bulk'
    render_on :view_issues_form_details_bottom, partial: 'change_author'
    render_on :view_issues_new_top, partial: 'new_ticket_message'
    render_on :view_issues_sidebar_issues_bottom, partial: 'issues/additionals_sidebar_issues'
    render_on :view_issues_sidebar_queries_bottom, partial: 'issues/additionals_sidebar_queries'
    render_on :view_my_account_preferences, partial: 'users/autowatch_involved_issue'
    render_on :view_users_form_preferences, partial: 'users/autowatch_involved_issue'
    render_on :view_users_show_contextual, partial: 'users/additionals_contextual'
    render_on :view_wiki_show_sidebar_bottom, partial: 'wiki/additionals_sidebar'

    def helper_issues_show_detail_after_setting(context = {})
      detail = context[:detail]
      return unless detail.prop_key == 'author_id'

      detail[:value] = find_name_by_reflection('author', detail.value) || detail.value
      detail[:old_value] = find_name_by_reflection('author', detail.old_value) || detail.old_value
    end

    def view_layouts_base_content(context = {})
      controller = context[:controller]
      return if controller.nil?

      controller_name = context[:controller].params[:controller]
      action_name = context[:controller].params[:action]

      return if controller_name == 'account' && action_name == 'login' ||
                controller_name == 'my' ||
                controller_name == 'account' && action_name == 'lost_password' ||
                !Additionals.setting?(:add_go_to_top)

      link_to l(:label_go_to_top), '#gototop', class: 'gototop'
    end
  end
end
