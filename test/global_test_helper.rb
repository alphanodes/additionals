module Additionals
  module GlobalTestHelper
    def with_additionals_settings(settings, &_block)
      saved_settings = Setting.plugin_additionals.dup
      new_settings = Setting.plugin_additionals.dup
      settings.each do |key, value|
        new_settings[key] = value
      end
      Setting.plugin_additionals = new_settings
      yield
    ensure
      Setting.plugin_additionals = saved_settings
    end

    def assert_query_sort_order(table_css, column, options = {})
      options[:action] = :index if options[:action].blank?
      column = column.to_s
      column_css = column.tr('_', '-')

      get options[:action],
          params: { sort: "#{column}:asc", c: [column] }

      assert_response :success
      assert_select "table.list.#{table_css}.sort-by-#{column_css}.sort-asc"

      get options[:action],
          params: { sort: "#{column}:desc", c: [column] }

      assert_response :success
      assert_select "table.list.#{table_css}.sort-by-#{column_css}.sort-desc"
    end
  end
end
