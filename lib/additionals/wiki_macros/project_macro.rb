# frozen_string_literal: true

module Additionals
  module WikiMacros
    module ProjectMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    List all active projects the current user is a member of, as a tree with homepage links.

    Syntax:

      {{projects([title=TITLE, with_create_issue=BOOL])}}

    Parameters:

      :param string title: title of the project list
      :param bool with_create_issue: show a "New issue" link for projects in which the user can add issues

    Examples:

      {{projects}}
      ...List all projects I am a member of

      {{projects(title=My project list)}}
      ...List all projects I am a member of with title "My project list"

      {{projects(with_create_issue=true)}}
      ...List all projects I am a member of with a link to create a new issue
        DESCRIPTION

        macro :projects do |_obj, args|
          _args, options = extract_macro_options args, :title, :with_create_issue
          @projects = User.current.projects.active.includes(:enabled_modules).sorted
          return unless @projects

          @html_options = { class: 'external' }
          render partial: 'wiki/project_macros',
                 formats: [:html],
                 locals: { projects: @projects,
                           list_title: options[:title],
                           with_create_issue: RedminePluginKit.true?(options[:with_create_issue]) }
        end
      end
    end
  end
end
