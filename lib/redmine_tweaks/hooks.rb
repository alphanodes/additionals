# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013,2014  AlphaNodes GmbH

module RedmineTweaks

  class RedmineTweaksHookListener < Redmine::Hook::ViewListener

    render_on(:view_layouts_base_html_head, :partial => 'global_header')
    render_on(:view_layouts_base_content, :partial => 'global_content')
    render_on(:view_layouts_base_body_bottom, :partial => 'global_footer')

    render_on(:view_issues_new_top, :partial => 'new_ticket_message')

    render_on(:view_projects_show_right, :partial => 'project_overview')
    render_on(:view_account_login_bottom, :partial => 'login_text')

    render_on(:view_projects_show_sidebar_bottom, :partial => 'global_sidebar')
    render_on(:view_issues_sidebar_queries_bottom, :partial => 'global_sidebar')
  end

  def self.settings() Setting[:plugin_redmine_tweaks] end

end
