# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015 AlphaNodes GmbH

module RedmineTweaks
  Redmine::WikiFormatting::Macros.register do
    
    desc <<-EOHELP
Display projects.

Syntax:

  {{list_projects(title=My project list,with_create_issue=BOOL)}}

Examples:

  {{list_projects}}
  ...List all project, which I am member of

  {{list_projects(title=My project list)}}
  ...List all project with title "My project list", which I am member of

  {{list_projects(with_create_issue=true)}}
  ...List all project with link to create new issue, which I am member of

EOHELP

    macro :list_projects do |obj, args|
      args, options = extract_macro_options(args, :title, :with_create_issue)
      @projects = RedmineTweaks.load_projects
      return '' if @projects.nil?

      @html_options = {:class => 'external'}
      render :partial => 'wiki/project_macros', :locals => {:projects => @projects,
        :list_title => options[:title],
        :with_create_issue => options[:with_create_issue]}
    end
  end

  def self.load_projects
    if ActiveRecord::VERSION::MAJOR < 4
      all_projects = Project.active.visible(User.current).find(:all, :order => "projects.name")
    else
      all_projects = Project.visible.sorted
    end
    my_projects = []
    all_projects.each do |p|
      if User.current.member_of?(p)
        my_projects << p
      end
    end
    my_projects
  end

end
