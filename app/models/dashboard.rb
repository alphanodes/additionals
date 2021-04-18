# frozen_string_literal: true

class Dashboard < ActiveRecord::Base
  include Redmine::I18n
  include Redmine::SafeAttributes
  include Additionals::EntityMethods

  class SystemDefaultChangeException < StandardError; end

  class ProjectSystemDefaultChangeException < StandardError; end

  belongs_to :project
  belongs_to :author, class_name: 'User'

  # current active project (belongs_to :project can be nil, because this is system default)
  attr_accessor :content_project

  serialize :options

  has_many :dashboard_roles, dependent: :destroy
  has_many :roles, through: :dashboard_roles

  VISIBILITY_PRIVATE = 0
  VISIBILITY_ROLES   = 1
  VISIBILITY_PUBLIC  = 2

  scope :by_project, (->(project_id) { where project_id: project_id if project_id.present? })
  scope :sorted, (-> { order "#{Dashboard.table_name}.name" })
  scope :welcome_only, (-> { where dashboard_type: DashboardContentWelcome::TYPE_NAME })
  scope :project_only, (-> { where dashboard_type: DashboardContentProject::TYPE_NAME })

  safe_attributes 'name', 'description', 'enable_sidebar',
                  'always_expose', 'project_id', 'author_id',
                  if: (lambda do |dashboard, user|
                    dashboard.new_record? ||
                      user.allowed_to?(:save_dashboards, dashboard.project, global: true)
                  end)

  safe_attributes 'dashboard_type',
                  if: (lambda do |dashboard, _user|
                    dashboard.new_record?
                  end)

  safe_attributes 'visibility', 'role_ids',
                  if: (lambda do |dashboard, user|
                    user.allowed_to?(:share_dashboards, dashboard.project, global: true) ||
                      user.allowed_to?(:set_system_dashboards, dashboard.project, global: true)
                  end)

  safe_attributes 'system_default',
                  if: (lambda do |dashboard, user|
                    user.allowed_to? :set_system_dashboards, dashboard.project, global: true
                  end)

  before_save :dashboard_type_check, :visibility_check, :set_options_hash, :clear_unused_block_settings

  before_destroy :check_destroy_system_default
  after_save :update_system_defaults
  after_save :remove_unused_role_relations

  validates :name, :dashboard_type, :author, :visibility, presence: true
  validates :visibility, inclusion: { in: [VISIBILITY_PUBLIC, VISIBILITY_ROLES, VISIBILITY_PRIVATE] }
  validate :validate_roles
  validate :validate_visibility
  validate :validate_name
  validate :validate_system_default
  validate :validate_project_system_default

  class << self
    def system_default(dashboard_type)
      select(:id).find_by(dashboard_type: dashboard_type, system_default: true)
                 .try(:id)
    end

    def default(dashboard_type, project = nil, user = User.current)
      recently_id = User.current.pref.recently_used_dashboard dashboard_type, project

      scope = where dashboard_type: dashboard_type
      scope = scope.where(project_id: project.id).or(scope.where(project_id: nil)) if project.present?

      dashboard = scope.visible.find_by id: recently_id if recently_id.present?

      if dashboard.blank?
        scope = scope.where(system_default: true).or(scope.where(author_id: user.id))
        dashboard = scope.order(system_default: :desc, project_id: :desc, id: :asc).first

        if recently_id.present?
          Rails.logger.debug 'default cleanup required'
          # Remove invalid recently_id
          if project.present?
            User.current.pref.recently_used_dashboards[dashboard_type].delete project.id
          else
            User.current.pref.recently_used_dashboards[dashboard_type] = nil
          end
        end
      end

      dashboard
    end

    def fields_for_order_statement(table = nil)
      table ||= table_name
      ["#{table}.name"]
    end

    def visible(user = User.current, **options)
      scope = left_outer_joins :project
      scope = scope.where(projects: { id: nil }).or(scope.where(Project.allowed_to_condition(user, :view_project, options)))

      if user.admin?
        scope.where.not(visibility: VISIBILITY_PRIVATE).or(scope.where(author_id: user.id))
      elsif user.memberships.any?
        scope.where("#{table_name}.visibility = ?" \
            " OR (#{table_name}.visibility = ? AND #{table_name}.id IN (" \
            "SELECT DISTINCT d.id FROM #{table_name} d"  \
            " INNER JOIN #{table_name_prefix}dashboard_roles#{table_name_suffix} dr ON dr.dashboard_id = d.id" \
            " INNER JOIN #{MemberRole.table_name} mr ON mr.role_id = dr.role_id" \
            " INNER JOIN #{Member.table_name} m ON m.id = mr.member_id AND m.user_id = ?" \
            " INNER JOIN #{Project.table_name} p ON p.id = m.project_id AND p.status <> ?" \
            ' WHERE d.project_id IS NULL OR d.project_id = m.project_id))' \
            " OR #{table_name}.author_id = ?",
                    VISIBILITY_PUBLIC,
                    VISIBILITY_ROLES,
                    user.id,
                    Project::STATUS_ARCHIVED,
                    user.id)
      elsif user.logged?
        scope.where(visibility: VISIBILITY_PUBLIC).or(scope.where(author_id: user.id))
      else
        scope.where visibility: VISIBILITY_PUBLIC
      end
    end
  end

  def initialize(attributes = nil, *args)
    super
    set_options_hash
  end

  def set_options_hash
    self.options ||= {}
  end

  def [](attr_name)
    if has_attribute? attr_name
      super
    else
      options ? options[attr_name] : nil
    end
  end

  def []=(attr_name, value)
    if has_attribute? attr_name
      super
    else
      h = (self[:options] || {}).dup
      h.update attr_name => value
      self[:options] = h
      value
    end
  end

  # Returns true if the dashboard is visible to +user+ or the current user.
  def visible?(user = User.current)
    return true if user.admin?
    return false unless project.nil? || user.allowed_to?(:view_project, project)
    return true if user == author

    case visibility
    when VISIBILITY_PUBLIC
      true
    when VISIBILITY_ROLES
      if project
        (user.roles_for_project(project) & roles).any?
      else
        user.memberships.joins(:member_roles).where(member_roles: { role_id: roles.map(&:id) }).any?
      end
    end
  end

  def content
    @content ||= "DashboardContent#{dashboard_type[0..-10]}".constantize.new(project: content_project.presence || project)
  end

  def available_groups
    content.groups
  end

  def layout
    self[:layout] ||= content.default_layout.deep_dup
  end

  def layout=(arg)
    self[:layout] = arg
  end

  def layout_settings(block = nil)
    s = self[:layout_settings] ||= {}
    if block
      s[block] ||= {}
    else
      s
    end
  end

  def layout_settings=(arg)
    self[:layout_settings] = arg
  end

  def remove_block(block)
    block = block.to_s.underscore
    layout.each_key do |group|
      layout[group].delete block
    end
    layout
  end

  # Adds block to the user page layout
  # Returns nil if block is not valid or if it's already
  # present in the user page layout
  def add_block(block)
    block = block.to_s.underscore
    return unless content.valid_block? block, layout.values.flatten

    remove_block block
    # add it to the first group
    # add it to the first group
    group = available_groups.first
    layout[group] ||= []
    layout[group].unshift block
  end

  # Sets the block order for the given group.
  # Example:
  #   preferences.order_blocks('left', ['issueswatched', 'news'])
  def order_blocks(group, blocks)
    group = group.to_s
    return if content.groups.exclude?(group) || blocks.blank?

    blocks = blocks.map(&:underscore) & layout.values.flatten
    blocks.each { |block| remove_block block }
    layout[group] = blocks
  end

  def update_block_settings(block, settings)
    block = block.to_s
    block_settings = layout_settings(block).merge(settings.symbolize_keys)
    layout_settings[block] = block_settings
  end

  def private?(user = User.current)
    author_id == user.id && visibility == VISIBILITY_PRIVATE
  end

  def public?
    visibility != VISIBILITY_PRIVATE
  end

  def editable_by?(usr = User.current, prj = nil)
    prj ||= project
    usr && (usr.admin? ||
           (author == usr && usr.allowed_to?(:save_dashboards, prj, global: true)))
  end

  def editable?(usr = User.current)
    @editable ||= editable_by? usr
  end

  def destroyable_by?(usr = User.current)
    return unless editable_by? usr, project

    return !system_default_was if dashboard_type != DashboardContentProject::TYPE_NAME

    # project dashboards needs special care
    project.present? || !system_default_was
  end

  def destroyable?
    @destroyable ||= destroyable_by? User.current
  end

  def to_s
    name
  end

  # Returns a string of css classes that apply to the entry
  def css_classes(user = User.current)
    s = ['dashboard']
    s << 'created-by-me' if author_id == user.id
    s.join ' '
  end

  def allowed_target_projects(user = User.current)
    Project.where Project.allowed_to_condition(user, :save_dashboards)
  end

  # this is used to get unique cache for blocks
  def async_params(block, options, settings)
    if block.blank?
      msg = 'block is missing for dashboard_async'
      Rails.log.error msg
      raise msg
    end

    config = { dashboard_id: id,
               block: block }

    if !options.key?(:skip_user_id) || !options[:skip_user_id]
      settings[:user_id] = User.current.id
      settings[:user_is_admin] = User.current.admin?
    end

    if settings.present?
      settings.each do |key, setting|
        settings[key] = setting.reject(&:blank?).join(',') if setting.is_a? Array

        next if options[:exposed_params].blank?

        options[:exposed_params].each do |exposed_param|
          if key == exposed_param
            config[key] = settings[key]
            settings.delete key
          end
        end
      end

      unique_params = settings.flatten
      unique_params += options[:unique_params].reject(&:blank?) if options[:unique_params].present?

      # Rails.logger.debug "debug async_params for #{block}: unique_params=#{unique_params.inspect}"
      config[:unique_key] = Digest::SHA256.hexdigest unique_params.join('_')
    end

    # Rails.logger.debug "debug async_params for #{block}: config=#{config.inspect}"

    config
  end

  def project_id_can_change?
    return true if new_record? ||
                   dashboard_type != DashboardContentProject::TYPE_NAME ||
                   !system_default_was ||
                   project_id_was.present?
  end

  private

  def clear_unused_block_settings
    blocks = layout.values.flatten
    layout_settings.keep_if { |block, _settings| blocks.include? block }
  end

  def remove_unused_role_relations
    return if !saved_change_to_visibility? || visibility == VISIBILITY_ROLES

    roles.clear
  end

  def validate_roles
    return if visibility != VISIBILITY_ROLES || roles.present?

    errors.add(:base,
               [l(:label_role_plural), l('activerecord.errors.messages.blank')].join(' '))
  end

  def validate_system_default
    return if new_record? ||
              system_default_was == system_default ||
              system_default? ||
              project_id.present?

    raise SystemDefaultChangeException
  end

  def validate_project_system_default
    return if project_id_can_change?

    raise ProjectSystemDefaultChangeException if project_id.present?
  end

  def check_destroy_system_default
    raise 'It is not allowed to delete dashboard, which is system default' unless destroyable?
  end

  def dashboard_type_check
    self.project_id = nil if dashboard_type == DashboardContentWelcome::TYPE_NAME
  end

  def update_system_defaults
    return unless system_default? && User.current.allowed_to?(:set_system_dashboards, project, global: true)

    scope = self.class
                .where(dashboard_type: dashboard_type)
                .where.not(id: id)

    scope = scope.where project: project if dashboard_type == DashboardContentProject::TYPE_NAME

    scope.update_all system_default: false
  end

  # check if permissions changed and dashboard settings have to be corrected
  def visibility_check
    user = User.current

    return if system_default? ||
              user.allowed_to?(:share_dashboards, project, global: true) ||
              user.allowed_to?(:set_system_dashboards, project, global: true)

    # change to private
    self.visibility = VISIBILITY_PRIVATE
  end

  def validate_visibility
    errors.add :visibility, :must_be_for_everyone if system_default? && visibility != VISIBILITY_PUBLIC
  end

  def validate_name
    return if name.blank?

    scope = self.class.visible.where name: name
    if dashboard_type == DashboardContentProject::TYPE_NAME
      scope = scope.project_only
      scope = scope.where project_id: project_id
      scope = scope.or scope.where(project_id: nil) if project_id.present?
    else
      scope = scope.welcome_only
    end

    scope = scope.where.not id: id unless new_record?
    errors.add :name, :name_not_unique if scope.count.positive?
  end
end
