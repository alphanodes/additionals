# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013,2014  AlphaNodes GmbH

module RedmineTweaks
  Redmine::WikiFormatting::Macros.register do
    
    desc <<-EOHELP
Display projects.  Examples:

  {{list_projects}}
  ...List all project, which I am member of

  {{list_projects(My project list)}}
  ...List all project with title "My project list", which I am member of

EOHELP

    macro :list_projects do |obj, args|
      @list_title = args[0]
      @projects = RedmineTweaks.load_projects
      return '' if @projects.nil?

      @html_options = {:class => 'external'}
      render :partial => 'wiki/project_macros', :locals => {:projects => @projects, :html_options => @html_options, :list_title => @list_title}
    end
  end
  
  def self.load_projects
    scope = Project  
    scope = scope.active
    all_projects = scope.visible(User.current).find(:all, :order => "projects.name")
    my_projects = []
    all_projects.each do |p|
      if User.current.member_of?(p)
        my_projects << p
      end
    end
    my_projects
  end

end
