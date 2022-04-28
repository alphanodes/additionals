# frozen_string_literal: true

module Additionals
  module WikiMacros
    module LastUpdatedByMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Displays a user who updated the page.

    Syntax:

    {{last_updated_by}}

    Scope:

    This macro only works in wiki page contexts.
        DESCRIPTION

        macro :last_updated_by do |obj, args|
          raise 'The correct usage is {{last_updated_by}}' unless args.empty?

          tag.span safe_join([avatar(obj.author, size: 14), ' ', link_to_user(obj.author)]),
                   class: 'last-updated-by'
        end
      end
    end
  end
end
