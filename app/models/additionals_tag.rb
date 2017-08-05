class AdditionalsTag
  def self.get_available_tags(klass, options = {}, permission = nil)
    table_name = klass.table_name
    scope = RedmineCrm::Tag.where({})
    scope = scope.where("#{Project.table_name}.id = ?", options[:project]) if options[:project]
    scope = scope.where(tag_access(permission))
    scope = scope.where("LOWER(#{RedmineCrm::Tag.table_name}.name) LIKE ?", "%#{options[:name_like].downcase}%") if options[:name_like]

    joins = []
    joins << "JOIN #{RedmineCrm::Tagging.table_name} " \
             "ON #{RedmineCrm::Tagging.table_name}.tag_id = #{RedmineCrm::Tag.table_name}.id "
    joins << "JOIN #{table_name} " \
             "ON #{table_name}.id = #{RedmineCrm::Tagging.table_name}.taggable_id " \
             "AND #{RedmineCrm::Tagging.table_name}.taggable_type = '#{klass}' "
    joins << "JOIN #{Project.table_name} ON #{table_name}.project_id = #{Project.table_name}.id "

    scope = scope.select("#{RedmineCrm::Tag.table_name}.*, " \
                          "COUNT(DISTINCT #{RedmineCrm::Tagging.table_name}.taggable_id) AS count")
    scope = scope.joins(joins.flatten)
    scope = scope.group("#{RedmineCrm::Tag.table_name}.id, #{RedmineCrm::Tag.table_name}.name").having('COUNT(*) > 0')
    scope = scope.order("#{RedmineCrm::Tag.table_name}.name")
    scope
  end

  def self.tag_access(permission)
    cond = ''
    projects_allowed = if permission.nil?
                         Project.visible.pluck(:id)
                       else
                         Project.where(Project.allowed_to_condition(User.current, permission)).pluck(:id)
                       end
    unless projects_allowed.empty?
      cond << "#{Project.table_name}.id IN (#{projects_allowed.join(',')})"
    end
    cond
  end

  def self.remove_unused_tags
    unused = RedmineCrm::Tag.find_by_sql(<<-SQL)
      SELECT * FROM tags WHERE id NOT IN (
        SELECT DISTINCT tag_id FROM taggings
      )
    SQL
    unused.each(&:destroy)
  end

  def self.sql_for_tags_field(klass, operator, value)
    compare   = operator.eql?('=') ? 'IN' : 'NOT IN'
    ids_list  = klass.tagged_with(value).map(&:id).push(0).join(',')
    "( #{klass.table_name}.id #{compare} (#{ids_list}) ) "
  end
end
