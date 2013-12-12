# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013  AlphaNodes GmbH

module RedmineTweaks

  class RedmineTweaksHookListener < Redmine::Hook::ViewListener
    render_on(:view_issues_new_top, :partial => 'new_ticket_message')

    render_on(:view_projects_show_right, :partial => 'project_overview')
    render_on(:view_account_login_bottom, :partial => 'login_text')

    render_on(:view_projects_show_sidebar_bottom, :partial => 'global_sidebar')
    render_on(:view_issues_sidebar_queries_bottom, :partial => 'global_sidebar')

    def view_layouts_base_html_head(context = {})
      if Setting.plugin_redmine_tweaks['external_urls'] == '1'
        javascript_include_tag('redmine_tweaks.js', :plugin => :redmine_tweaks)
      elsif Setting.plugin_redmine_tweaks['external_urls'] == '2'
        javascript_include_tag('redmine_tweaks_anonymize.js', :plugin => :redmine_tweaks)
      end
    end

  end

  def self.settings() Setting[:plugin_redmine_tweaks] end

end
