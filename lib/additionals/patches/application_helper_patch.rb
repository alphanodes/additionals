# frozen_string_literal: true

module Additionals
  module Patches
    # Pipe Redmine-Core helpers that build a project list outside of
    # `Project.visible` through `Project.listable` so other plugins can
    # subtract certain project kinds from those listings (see the
    # canonical `Project.listable` scope in `project_patch.rb`).
    #
    # principals_options_for_select brings the assignee list of Redmine 7.1
    # to Redmine 7.0 (https://www.redmine.org/issues/44021), see below.
    module ApplicationHelperPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def projects_for_jump_box(user = User.current)
          return [] unless user.logged?

          user.projects.active
              .merge(Project.listable)
              .select(:id, :name, :identifier, :lft, :rgt)
              .to_a
        end

        # Copy of Redmine 7.1, which lists the author of the latest note among the involved
        # principals (https://www.redmine.org/issues/44021). Core 7.0 builds this list inside the method, so it cannot be
        # extended. On 7.1 the result is the same as core.
        # TODO(Redmine 7.0 EOL): drop this copy and principal_optgroups_by_display_format.
        def principals_options_for_select(collection, selected = nil)
          s = +''
          s << content_tag('option', "<< #{l :label_me} >>", value: User.current.id) if collection.include? User.current

          involved_principals = []
          # This optgroup is displayed only when editing a single issue
          if @issue.present? && !@issue.new_record?
            involved_principals = @issue.involved_principals.map do |principal|
              [principal, { disabled: collection.exclude?(principal) }]
            end
          end

          users, groups = collection.sort.partition { |principal| principal.is_a? User }
          if involved_principals.blank? && groups.blank?
            s << principals_option_tags(users, selected)
          else
            optgroups = [[l(:label_involved_principals), involved_principals]]
            optgroups.concat principal_optgroups_by_display_format(users, groups)

            optgroups.each do |label, principals|
              options_html = principals_option_tags principals, selected
              s << %(<optgroup label="#{h label}">#{options_html}</optgroup>) if options_html.present?
            end
          end
          s.html_safe # rubocop:disable Rails/OutputSafety
        end

        private

        def principal_optgroups_by_display_format(users, groups)
          case Setting.assignee_dropdown_display_format.to_s
          when 'groups_then_users'
            [[l(:label_group_plural), groups], [l(:label_user_plural), users]]
          when 'users_by_group'
            principal_users_by_group_optgroups_for_select users, groups
          else
            # Default to 'users_then_groups'
            [[l(:label_user_plural), users], [l(:label_group_plural), groups]]
          end
        end
      end
    end
  end
end
