# frozen_string_literal: true

class DashboardContent
  include Redmine::I18n

  attr_accessor :user, :project

  MAX_MULTIPLE_OCCURS = 8
  DEFAULT_MAX_ENTRIES = 10
  RENDER_ASYNC_CACHE_EXPIRES_IN = 30

  class << self
    def types
      descendants.map { |dc| dc::TYPE_NAME }
    end
  end

  def with_chartjs?
    false
  end

  def initialize(attr = {})
    self.user = attr[:user].presence || User.current
    self.project = attr[:project].presence
  end

  def groups
    %w[top left right bottom]
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
                  partial: 'dashboards/blocks/text' },
      'text_async' => { label: l(:label_text_async),
                        max_occurs: MAX_MULTIPLE_OCCURS,
                        async: { required_settings: %i[text],
                                 partial: 'dashboards/blocks/text_async' } },
      'news' => { label: l(:label_news_latest),
                  permission: :view_news,
                  if: proc { Redmine::AccessControl.active_module?(:news) } },
      'documents' => { label: l(:label_document_plural),
                       permission: :view_documents,
                       if: proc { Redmine::AccessControl.active_module?(:documents) } },
      'my_spent_time' => { label: l(:label_my_spent_time),
                           permission: :log_time },
      'feed' => { label: l(:label_additionals_feed),
                  max_occurs: 20,
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
    block.to_s =~  /\A(.*?)(__\d+)?\z/
    name = Regexp.last_match 1
    available_blocks.key?(name) ? available_blocks[name].merge(name: name) : nil
  end

  # Returns the default layout for a new dashboard
  def default_layout
    {
      'left' => ['legacy_left'],
      'right' => ['legacy_right']
    }
  end

  private

  def issues_cache_expires_in
    open_issue_count = Rails.cache.fetch issues_cache_key, expires_in: 1.hour do
      query = if project
                IssueQuery.new project: project, name: '_'
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
