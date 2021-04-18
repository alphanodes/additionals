# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Display projects.

  Syntax:

    {{projects([title=My project list, with_create_issue=BOOL])}}

  Examples:

    {{projects}}
    ...List all project, which I am member of

    {{projects(title=My project list)}}
    ...List all project with title "My project list", which I am member of

    {{projects(with_create_issue=true)}}
    ...List all project with link to create new issue, which I am member of
      DESCRIPTION

      macro :projects do |_obj, args|
        _args, options = extract_macro_options args, :title, :with_create_issue
        @projects = User.current.projects.active.includes(:enabled_modules).sorted
        return if @projects.nil?

        @html_options = { class: 'external' }
        render partial: 'wiki/project_macros',
               formats: [:html],
               locals: { projects: @projects,
                         list_title: options[:title],
                         with_create_issue: options[:with_create_issue] }
      end
    end
  end
end
