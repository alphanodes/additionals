# frozen_string_literal: true

module Additionals
  module Patches
    module WikiPagePatch
      extend ActiveSupport::Concern

      class_methods do
        # Pages of a wiki that were changed within the last days, newest change first.
        #
        # Shared by the recently_updated macro and by plugins that render the same
        # list outside of a wiki page, so both list the same pages.
        #
        # The visible scope is added by a plugin and does not exist in a plain
        # additionals install, hence the respond_to? check.
        #
        # @param wiki [Wiki]
        # @param days [Integer] number of days to look back
        # @param limit [Integer, nil] maximum number of pages, no limit if blank
        # @param user [User] user the pages have to be visible for
        # @return [ActiveRecord::Relation]
        def recently_updated(wiki, days: 7, limit: nil, user: User.current)
          scope = joins(:content)
                  .includes(:content)
                  .where(wiki_id: wiki.id)
                  .where(wiki_contents: { updated_on: (user.today - days).. })
                  .order(wiki_contents: { updated_on: :desc })

          scope = scope.visible user, project: wiki.project if respond_to? :visible
          scope = scope.limit limit.to_i if limit.to_i.positive?

          scope
        end
      end
    end
  end
end
