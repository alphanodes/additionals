class AdditionalsTag
  TAG_TABLE_NAME = RedmineCrm::Tag.table_name if defined? RedmineCrm
  TAGGING_TABLE_NAME = RedmineCrm::Tagging.table_name if defined? RedmineCrm
  PROJECT_TABLE_NAME = Project.table_name

  class << self
    def all_type_tags(klass, options = {})
      RedmineCrm::Tag.where({})
                     .joins(tag_joins(klass, options))
                     .distinct
                     .order("#{TAG_TABLE_NAME}.name")
    end

    def get_available_tags(klass, options = {})
      scope = RedmineCrm::Tag.where({})
      scope = scope.where("#{PROJECT_TABLE_NAME}.id = ?", options[:project]) if options[:project]
      if options[:permission]
        scope = scope.where(tag_access(options[:permission]))
      elsif options[:visible_condition]
        scope = scope.where(klass.visible_condition(User.current))
      end
      scope = scope.where("LOWER(#{TAG_TABLE_NAME}.name) LIKE ?", "%#{options[:name_like].downcase}%") if options[:name_like]
      scope = scope.where("#{TAG_TABLE_NAME}.name=?", options[:name]) if options[:name]
      scope = scope.where("#{TAGGING_TABLE_NAME}.taggable_id!=?", options[:exclude_id]) if options[:exclude_id]
      scope = scope.where(options[:where_field] => options[:where_value]) if options[:where_field].present? && options[:where_value]

      scope.select("#{TAG_TABLE_NAME}.*, COUNT(DISTINCT #{TAGGING_TABLE_NAME}.taggable_id) AS count")
           .joins(tag_joins(klass, options))
           .group("#{TAG_TABLE_NAME}.id, #{TAG_TABLE_NAME}.name").having('COUNT(*) > 0')
           .order("#{TAG_TABLE_NAME}.name")
    end

    def remove_unused_tags
      unused = RedmineCrm::Tag.find_by_sql(<<-SQL)
        SELECT * FROM tags WHERE id NOT IN (
          SELECT DISTINCT tag_id FROM taggings
        )
      SQL
      unused.each(&:destroy)
    end

    def sql_for_tags_field(klass, operator, value)
      compare   = operator.eql?('=') ? 'IN' : 'NOT IN'
      ids_list  = klass.tagged_with(value).collect(&:id).push(0).join(',')
      "( #{klass.table_name}.id #{compare} (#{ids_list}) ) "
    end

    private

    def tag_access(permission)
      projects_allowed = if permission.nil?
                           Project.visible.pluck(:id)
                         else
                           Project.where(Project.allowed_to_condition(User.current, permission)).pluck(:id)
                         end

      if projects_allowed.present?
        "#{PROJECT_TABLE_NAME}.id IN (#{projects_allowed.join(',')})" unless projects_allowed.empty?
      else
        '1=0'
      end
    end

    def tag_joins(klass, options = {})
      table_name = klass.table_name

      joins = ["JOIN #{TAGGING_TABLE_NAME} ON #{TAGGING_TABLE_NAME}.tag_id = #{TAG_TABLE_NAME}.id"]
      joins << "JOIN #{table_name} " \
               "ON #{table_name}.id = #{TAGGING_TABLE_NAME}.taggable_id AND #{TAGGING_TABLE_NAME}.taggable_type = '#{klass}'"

      if options[:project_join]
        joins << options[:project_join]
      elsif options[:project] || !options[:without_projects]
        joins << "JOIN #{PROJECT_TABLE_NAME} ON #{table_name}.project_id = #{PROJECT_TABLE_NAME}.id"
      end

      joins
    end
  end
end
