# frozen_string_literal: true

module GlobalSearch
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

    def search(query, user:, project: nil, scope: nil, types: nil, titles_only: false, limit: 10)
      projects = resolve_projects scope, user, project
      keyword = keyword_search query, user: user, projects: projects, types: types, titles_only: titles_only, limit: limit
      semantic = provider_search query, user: user, project: project, limit: 5

      # Deduplicate: remove semantic hits already in keyword results
      if semantic && keyword.present?
        keyword_ids = keyword.filter_map { |r| r[:id] }
        semantic[:results].reject! { |r| keyword_ids.include? r[:id] }
        semantic = nil if semantic[:results].blank?
      end

      { keyword: keyword, semantic: semantic }
    end

    private

    def resolve_projects(scope, user, project)
      case scope
      when 'bookmarks'
        Project.where id: user.bookmarked_project_ids
      when 'my_projects'
        user.projects
      else
        project ? [project] : nil
      end
    end

    def keyword_search(query, user:, projects: nil, types: nil, titles_only: false, limit: 10)
      scope = types.present? ? Array(types) & Redmine::Search.available_search_types : Redmine::Search.available_search_types
      fetcher = Redmine::Search::Fetcher.new query, user, scope, projects, all_words: true, titles_only: titles_only
      return [] if fetcher.tokens.blank?

      results = fetcher.results 0, limit
      results.filter_map do |record|
        format_record record
      rescue StandardError => e
        Rails.logger.warn "GlobalSearch: Failed to format record #{record.class}##{record.id}: #{e.message}"
        nil
      end
    end

    def provider_search(query, user:, project: nil, limit: 5)
      results = { label: nil, results: [] }
      providers.each do |provider|
        next unless user_can_use? provider, user, project

        hits = provider.search query, user: user, project: project, limit: limit
        next if hits.blank?

        results[:label] ||= I18n.t provider.label
        results[:results].concat hits
      rescue StandardError => e
        Rails.logger.warn "GlobalSearch: Provider #{provider.name} failed: #{e.message}"
      end
      results[:results].present? ? results : nil
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
