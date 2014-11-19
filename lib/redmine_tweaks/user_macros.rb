# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013,2014  AlphaNodes GmbH

module RedmineTweaks
  Redmine::WikiFormatting::Macros.register do
    
    desc <<-EOHELP
Display users.  Examples:

  {{list_users}}
  ...List all users for all projects

  {{list_users(123)}}
  ...A box showing all members for the project 123

  {{list_users(the-identifier)}}
  ...A box showing all members for the project with the identifier of 'the-identifier'

  {{list_users('My project name')}}
  ...A box showing all members for the project named 'My project name'

  {{list_users('My project name', Manager)}}
  ...A box showing all managers for the project named 'My project name'

EOHELP

    macro :list_users do |obj, args|
      project_id = args[0]
      roles_limit = args[1]
      @list_title = args[2]

      if project_id.present?
        project_id.strip!
        
        project = Project.visible.find_by_id(project_id)
        project ||= Project.visible.find_by_identifier(project_id)
        project ||= Project.visible.find_by_name(project_id)
        return '' if project.nil?

        raw_users = User.active.find(:all, :conditions => ["#{User.table_name}.id IN (SELECT DISTINCT user_id FROM members WHERE project_id=(?))", project.id]).sort
        return '' if raw_users.nil?

        users = [];
        raw_users.each {|user| 
          user['role'] = user.roles_for_project(project)
          if !roles_limit.present? or RedmineTweaks.check_role_matches(user['role'], roles_limit)
            users <<  user
          end
        }
      else
        project_ids = Project.all(:conditions => Project.visible_condition(User.current)).collect(&:id)
        if project_ids.any?
          # members of the user's projects
          users = User.active.find(:all, :conditions => ["#{User.table_name}.id IN (SELECT DISTINCT user_id FROM members WHERE project_id IN (?))", project_ids]).sort
        else
          return ''
        end
      end
      render :partial => 'wiki/user_macros', :locals => {:users => users}
    end
  end  
  
  def self.check_role_matches(roles, filters)
    filters.gsub('|', ',' ).split(',').each {|filter|
      roles.each {|role|
        if filter.to_s() == role.to_s()
          return true
        end
      }
    }
    return false 
  end
end
