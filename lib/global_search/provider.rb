# frozen_string_literal: true

module GlobalSearch
  # Base of a provider, which answers the global search from a source of its
  # own. A subclass answers as class methods:
  #
  # - search_type, label (locale key), icon and permission (nil for everyone)
  # - search_types: the types it answers for, empty while it is not set up
  # - search(query, user:, project:, projects:, limit:, types:)
  class Provider
    extend RedminePluginKit::Extensions::Abstract

    abstract!
  end
end
