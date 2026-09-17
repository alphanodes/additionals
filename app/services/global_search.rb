# frozen_string_literal: true

module GlobalSearch
  QUICK_JUMP_PATTERN = /\A#(\d+)\z/

  class << self
    # Provider API - only for extra sources (e.g. semantic search from redmine_ai)
    def providers
      @providers ||= []
    end

    def register(provider_class)
      providers << provider_class unless providers.include? provider_class
    end

    def load_providers
      Rails.root.glob('plugins/*/lib/global_search/*_provider.rb').each do |file|
        require_dependency file
      rescue StandardError => e
        Rails.logger.warn "GlobalSearch: Failed to load #{file}: #{e.message}"
      end
    end

    # Keyword results only. The providers answer in a request of their own (see
    # provider_search), so the keyword results never wait for an external service.
    def search(query, user:, project: nil, scope: nil, types: nil, titles_only: false, limit: 10)
      # Quick-jump: direct ID lookup
      if (jump = quick_jump query, user: user, types: types)
        return { keyword: jump, jump: true }
      end

      projects = resolve_projects scope, user, project
      { keyword: keyword_search(query, user: user, projects: projects, types: types, titles_only: titles_only, limit: limit),
        jump: false }
    end

    # The client deduplicates the hits against the keyword results it already shows, over
    # the url: an id alone is not unique across types, and a provider may identify a record
    # differently than the keyword search does (a wiki page by its content id, for instance).
    def provider_search(query, user:, project: nil, limit: 5, types: nil, keyword_hits: false)
      return if skip_providers? query, keyword_hits

      results = { label: nil, results: [] }
      usable_providers(user, project).each do |provider|
        hits = provider.search query, user: user, project: project, limit: limit, types: types
        next if hits.blank?

        results[:label] ||= I18n.t provider.label
        results[:results].concat hits
      rescue StandardError => e
        Rails.logger.warn "GlobalSearch: Provider #{provider.name} failed: #{e.message}"
      end
      results[:results].present? ? results : nil
    end

    # The search types at least one provider can answer for the user. The client only asks
    # the providers and shows a loading state when the active type is among them.
    def provider_search_types(user:, project: nil)
      types = usable_providers(user, project).flat_map do |provider|
        provider.respond_to?(:search_types) ? provider.search_types : Redmine::Search.available_search_types
      end
      types.uniq!
      types
    end

    def provider_label(user:, project: nil)
      provider = usable_providers(user, project).first
      provider ? I18n.t(provider.label) : nil
    end

    private

    # Runs on every page for the search dialog, so a failing provider must not take the page down.
    def usable_providers(user, project)
      providers.select do |provider|
        (!provider.respond_to?(:available?) || provider.available?) && user_can_use?(provider, user, project)
      rescue StandardError => e
        Rails.logger.warn "GlobalSearch: Provider #{provider.name} unusable: #{e.message}"
        false
      end
    end

    # An issue comes first: it is what an id reference means in Redmine, and the client
    # preselects the first hit so Enter opens it.
    def quick_jump(query, user:, types: nil)
      return unless (m = query.match QUICK_JUMP_PATTERN)

      id = m[1].to_i
      classes = searchable_classes types: types
      results = []
      ((classes & [Issue]) + (classes - [Issue])).each do |klass|
        record = klass.visible(user).find_by id: id
        next unless record

        results << format_record(record)
      rescue StandardError
        next
      end
      results.presence
    end

    def searchable_classes(types: nil)
      search_types = types.present? ? Array(types) & Redmine::Search.available_search_types : Redmine::Search.available_search_types
      search_types.filter_map do |type|
        type.singularize.classify.safe_constantize
      end
    end

    def resolve_projects(scope, user, project)
      case scope
      when 'bookmarks'
        Project.listable.where id: user.bookmarked_project_ids
      when 'my_projects'
        user.projects
      else
        project ? [project] : nil
      end
    end

    def keyword_search(query, user:, projects: nil, types: nil, titles_only: false, limit: 10)
      scope = types.present? ? Array(types) & Redmine::Search.available_search_types : Redmine::Search.available_search_types
      # live_search: true marks this as a live preview call (modal autocomplete),
      # distinct from the full /search page. Plugins like alphanodes_enterprise_support
      # may use it to switch to faster query strategies. Upstream Redmine ignores it.
      fetcher = Redmine::Search::Fetcher.new query, user, scope, projects,
                                             all_words: true,
                                             titles_only: titles_only,
                                             live_search: true
      return [] if fetcher.tokens.blank?

      results = fetcher.results 0, limit
      results.filter_map do |record|
        format_record record
      rescue StandardError => e
        Rails.logger.warn "GlobalSearch: Failed to format record #{record.class}##{record.id}: #{e.message}"
        nil
      end
    end

    # A bare number carries no meaning a semantic provider could pick up, and asking anyway
    # costs an external request. An id reference (#1234) never reaches the providers: the
    # keyword search finds every text referencing an id that starts with those digits,
    # which says nothing about its meaning. A plain number only does when the keyword search
    # found it, because then it means something (an error code, a year).
    def skip_providers?(query, keyword_hits)
      return true if query.match? QUICK_JUMP_PATTERN

      !keyword_hits && query.match?(/\A\d+\z/)
    end

    def format_record(record)
      url = record.event_url
      url = Rails.application.routes.url_helpers.url_for url.merge(only_path: true) if url.is_a? Hash

      {
        id: record.id,
        title: record.event_title,
        url: url,
        description: record.event_description&.truncate(120),
        project_name: record.respond_to?(:project) ? record.project&.name : nil,
        type: type_label(record)
      }
    end

    def type_label(record)
      type_key = record.class.name.underscore
      I18n.t "label_#{type_key}_plural", default: type_key.pluralize.humanize
    end

    def user_can_use?(provider, user, project)
      permission = provider.permission
      return true if permission.nil?

      if project
        user.allowed_to? permission, project
      else
        user.allowed_to? permission, nil, global: true
      end
    end
  end
end
