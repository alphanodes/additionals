# Project wiki macros
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
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

  EOHELP

      macro :projects do |_obj, args|
        args, options = extract_macro_options(args, :title, :with_create_issue)
        @projects = Additionals.load_projects
        return '' if @projects.nil?

        @html_options = { class: 'external' }
        render partial: 'wiki/project_macros', locals:  { projects: @projects,
                                                          list_title: options[:title],
                                                          with_create_issue: options[:with_create_issue] }
      end
    end
  end

  def self.load_projects
    all_projects = if ActiveRecord::VERSION::MAJOR < 4
                     Project.active.visible(User.current).find(:all, order: 'projects.name')
                   else
                     Project.active.visible.sorted
                   end
    my_projects = []
    all_projects.each do |p|
      my_projects << p if User.current.member_of?(p)
    end
    my_projects
  end
end
