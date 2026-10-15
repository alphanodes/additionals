# frozen_string_literal: true

class DashboardContent
  include Redmine::I18n

  attr_accessor :user, :project

  MAX_MULTIPLE_OCCURS = 8
  DEFAULT_MAX_ENTRIES = 10
  RENDER_ASYNC_CACHE_EXPIRES_IN = 30

  # Groups spanning the full width as their own row (as opposed to the 50%
  # left/right columns). Empty ones may be skipped in read-only layouts.
  FULL_WIDTH_GROUPS = %w[top bottom].freeze

  # Settings many blocks share, see Additionals::SettingsSchema
  TITLE_SETTING = { type: :string, label: :field_title }.freeze
  MAX_ENTRIES_SETTING = { type: :integer, label: :label_max_entries, min: 1, max: 100,
                          default: DEFAULT_MAX_ENTRIES }.freeze
  # Settings form of query list blocks without an own one
  QUERY_LIST_SETTINGS_PARTIAL = 'dashboards/blocks/query_list'

  class << self
    def types
      descendants.map { |dc| dc::TYPE_NAME }
    end

    # Saved queries a block of the project can show, exactly of this class
    # (not e.g. a subclass of another plugin)
    def selectable_queries(klass, project)
      klass.visible
           .global_or_on_project(project)
           .where(type: klass.to_s)
           .sorted
    end
  end

  def initialize(attr = {})
    self.user = attr[:user].presence || User.current
    self.project = attr[:project].presence
  end

  def groups
    %w[top left right bottom]
  end

  def full_width_group?(group)
    FULL_WIDTH_GROUPS.include? group.to_s
  end

  # The 50% column groups (left/right) as opposed to the full-width rows.
  def column_groups
    groups - FULL_WIDTH_GROUPS
  end

  def block_definitions
    {
      'issuequery' => { label: l(:label_query_with_name, l(:label_issue_plural)),
                        permission: :view_issues,
                        query_block: {
                          label: l(:label_issue_plural),
                          list_partial: 'issues/list',
                          class: IssueQuery,
                          link_helper: '_project_issues_path',
                          count_method: 'issue_count',
                          entries_method: 'issues',
                          entities_var: :issues,
                          with_project: true
                        },
                        max_occurs: MAX_MULTIPLE_OCCURS },
      'text' => { label: l(:label_text_sync),
                  max_occurs: MAX_MULTIPLE_OCCURS,
                  settings: text_settings,
                  partial: 'dashboards/blocks/text' },
      'text_async' => { label: l(:label_text_async),
                        max_occurs: MAX_MULTIPLE_OCCURS,
                        settings: text_settings,
                        async: { required_settings: %i[text],
                                 partial: 'dashboards/blocks/text_async' } },
      'news' => { label: l(:label_news_latest),
                  permission: :view_news,
                  settings: { max_entries: MAX_ENTRIES_SETTING.merge(max: 1000),
                              with_subprojects: { type: :boolean, label: :label_cross_project_descendants,
                                                  if: ->(_schema) { project.present? } } },
                  if: proc { Redmine::AccessControl.active_module?(:news) } },
      'documents' => { label: l(:label_document_plural),
                       permission: :view_documents,
                       settings: { max_entries: MAX_ENTRIES_SETTING.merge(max: 1000) },
                       if: proc { Redmine::AccessControl.active_module?(:documents) } },
      'my_spent_time' => { label: l(:label_my_spent_time),
                           permission: :log_time,
                           settings: { days: { type: :integer, label: :label_day_plural, min: 1, max: 365, default: 7 } } },
      'feed' => { label: l(:label_additionals_feed),
                  max_occurs: 20,
                  settings: { title: TITLE_SETTING,
                              url: { type: :string, label: :field_url, required: true },
                              max_entries: MAX_ENTRIES_SETTING },
                  async: { required_settings: %i[url],
                           cache_expires_in: 600,
                           skip_user_id: true,
                           partial: 'dashboards/blocks/feed' } }
    }
  end

  # Returns the available blocks
  def available_blocks
    return @available_blocks if defined? @available_blocks

    available_blocks = block_definitions.reject do |_block_name, block_specs|
      block_specs.key?(:permission) && !block_permission_allowed?(block_specs[:permission]) ||
        block_specs.key?(:admin_only) && block_specs[:admin_only] && !user.admin? ||
        block_specs.key?(:if) && !block_specs[:if].call(project)
    end

    @available_blocks = available_blocks.sort_by { |_k, v| v[:label] }.to_h
  end

  def block_options(blocks_in_use = [])
    options = []
    available_blocks.each do |block, block_options|
      indexes = blocks_in_use.map do |n|
        Regexp.last_match(2).to_i if n =~ /\A#{block}(__(\d+))?\z/
      end
      indexes.compact!

      occurs = indexes.size
      block_id = indexes.any? ? "#{block}__#{indexes.max + 1}" : block
      disabled = (occurs >= (available_blocks[block][:max_occurs] || 1))
      block_id = nil if disabled

      options << [block_options[:label], block_id]
    end
    options
  end

  def valid_block?(block, blocks_in_use = [])
    block.present? && block_options(blocks_in_use).map(&:last).include?(block)
  end

  def find_block(block)
    block.to_s =~ /\A(.*?)(__\d+)?\z/
    name = Regexp.last_match 1
    available_blocks.key?(name) ? available_blocks[name].merge(name:) : nil
  end

  # Definition of a block, whether or not the current user may use it
  def block_definition(block)
    # Plugins may query the database while building the definitions
    @all_block_definitions ||= block_definitions
    @all_block_definitions[block_name(block)]
  end

  # Name of the block definition of a block id, e.g. feed for feed__2
  def block_name(block)
    block.to_s.sub(/__\d+\z/, '')
  end

  # Settings a block declares, nil if it declares none: such a block keeps
  # every setting it gets. Query list blocks with the settings form of
  # additionals declare the settings of that form.
  def block_settings_definitions(block)
    settings_definitions_of block_definition(block)
  end

  # Settings of a block with the given values, completed by its stored ones,
  # see Additionals::SettingsSchema. Nil for blocks without declared settings.
  def block_settings(block, values: {}, stored: {}, dashboard: nil)
    settings_schema settings_definitions_of(block_definition(block)), values, dashboard, stored:
  end

  # The blocks the user can add, with their settings, for programmatic clients
  def available_block_schemas(dashboard: nil)
    available_blocks.to_h do |name, definition|
      [name, { label: definition[:label],
               max_occurs: definition[:max_occurs] || 1,
               settings: settings_schema(settings_definitions_of(definition), {}, dashboard)&.describe }]
    end
  end

  # Returns the default layout for a new dashboard
  def default_layout
    {
      'left' => ['legacy_left'],
      'right' => ['legacy_right']
    }
  end

  private

  def settings_definitions_of(definition)
    return if definition.nil?
    return {} if definition[:no_settings]
    return definition[:settings] if definition.key? :settings

    query_list_settings definition[:query_block][:class] if default_query_list_settings? definition
  end

  def settings_schema(definitions, values, dashboard, stored: {})
    return if definitions.nil?

    Additionals::SettingsSchema.new definitions, values, stored:, user:, project:, dashboard:
  end

  # Without a text the blocks show a hint, so it is no required setting
  def text_settings
    { title: TITLE_SETTING,
      text: { type: :text, label: :label_text_sync } }
  end

  def default_query_list_settings?(definition)
    definition[:query_block].present? &&
      definition[:settings_partial].blank? &&
      definition.dig(:async, :partial).in?([nil, QUERY_LIST_SETTINGS_PARTIAL])
  end

  def query_list_settings(klass)
    { query_id: { type: :enum, label: :label_query, required: true,
                  values: ->(_schema) { self.class.selectable_queries(klass, project).map { |query| [query.name, query.id.to_s] } } },
      columns: { type: :list, label: :field_column_names,
                 values: ->(schema) { query_list_columns klass, schema[:query_id] } },
      max_entries: MAX_ENTRIES_SETTING,
      auto_refresh: { type: :boolean, label: :label_enable_auto_refresh } }
  end

  # Columns of the chosen query as its settings form offers them (without a
  # project), nil without a query: then there is nothing to check
  def query_list_columns(klass, query_id)
    query = klass.find_by id: query_id if query_id.present?
    return if query.nil?

    query.available_columns.filter_map { |column| [column.caption, column.name.to_s] unless column.frozen? }
  end

  def issues_cache_expires_in
    open_issue_count = Rails.cache.fetch issues_cache_key, expires_in: 1.hour do
      query = if project
                IssueQuery.new project:, name: '_'
              else
                IssueQuery.new name: '_'
              end
      query.issue_count
    end

    if open_issue_count > 1_000
      86_400 # 1 day
    elsif open_issue_count > 500
      14_400 # 4 hour
    elsif open_issue_count > 200
      3_600 # 1 hour
    elsif open_issue_count > 100
      1_800 # 30 minutes
    else
      60
    end
  end

  def issues_cache_key
    Digest::SHA256.hexdigest [project&.id, User.current.id].compact.join('-')
  end

  # if more the one permission is specified, all permissions are required
  def block_permission_allowed?(permission)
    Array(permission).all? { |p| user.allowed_to? p, project, global: true }
  end
end
