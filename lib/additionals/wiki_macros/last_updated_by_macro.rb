# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Displays a user who updated the page.
    {{last_updated_by}}
      DESCRIPTION

      macro :last_updated_by do |obj, args|
        raise 'The correct usage is {{last_updated_by}}' unless args.empty?

        tag.span safe_join([avatar(obj.author, size: 14), ' ', link_to_user(obj.author)]),
                 class: 'last-updated-by'
      end
    end
  end
end
