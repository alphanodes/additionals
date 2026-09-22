# frozen_string_literal: true

module Additionals
  module WikiMacros
    module NewIssueMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Create a "New issue" link for the current user.

    Nothing is shown if the project does not exist, is not visible or the current user
    is not allowed to add issues.

    Syntax:

      {{new_issue([PROJECT_NAME, name=NAME])}}

      PROJECT_NAME can be project identifier, project name or project id.

      If no PROJECT_NAME is specified, the first project is used in which the current
      user can add issues and be assigned.

    Parameters:

      :param string project_name: project identifier, project name or project id
      :param string name: link text (default "New issue"). Use a language suffix for
                          a translated text, e.g. name_de, name_it, name_es

    Examples:

      Link to create new issue in first available project:
      {{new_issue}}
      Link to create new issue in project with the identifier of 'the-identifier':
      {{new_issue(the-identifier)}}
      Link to create new issue in project with the identifier of 'the-identifier'
      and the name 'New issue for broken displays'
      {{new_issue(the-identifier, name=New issue for broken displays)}}
        DESCRIPTION

        macro :new_issue do |_obj, args|
          if args.any?
            args, options = extract_macro_options(args, *additionals_titles_for_locale(:name))
            i18n_name = additionals_i18n_title options, :name
            project_id = args[0]
          end
          i18n_name = l :label_issue_new if i18n_name.blank?

          if project_id.present?
            project_id.strip!

            project = Project.visible.find_by id: project_id
            project ||= Project.visible.find_by identifier: project_id
            project ||= Project.visible.find_by name: project_id
            return '' if project.nil? || !User.current.allowed_to?(:add_issues, project)

            return link_to sprite_icon('add', i18n_name), new_project_issue_path(project), class: 'macro-new-issue icon icon-add'
          else
            @memberships = User.current
                               .memberships
                               .preload(:roles, :project)
                               .where(Project.visible_condition(User.current))
                               .to_a
            if @memberships.present?
              project_url = memberships_new_issue_project_url User.current, @memberships, :add_issues
              return link_to sprite_icon('add', i18n_name), project_url, class: 'macro-new-issue icon icon-add' if project_url.present?
            end
          end

          ''
        end
      end
    end
  end
end
