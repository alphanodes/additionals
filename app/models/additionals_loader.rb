# frozen_string_literal: true

class AdditionalsLoader
  class ExistingControllerPatchForHelper < StandardError; end

  attr_accessor :plugin_id, :debug

  DEFAULT_PLUGIN_ID = 'additionals'

  class << self
    def default_settings(plugin_id = DEFAULT_PLUGIN_ID)
      cached_settings_name = "@default_settings_#{plugin_id}"
      cached_settings = instance_variable_get cached_settings_name
      if cached_settings.nil?
        data = yaml_config_load 'settings.yml', with_erb: true, plugin_id: plugin_id
        instance_variable_set cached_settings_name, data.symbolize_keys
      else
        cached_settings
      end
    end

    def yaml_config_load(yaml_file, plugin_id: DEFAULT_PLUGIN_ID, with_erb: false)
      file_to_load = File.read File.join(plugin_dir(plugin_id), 'config', yaml_file)
      file_to_load = ERB.new(file_to_load).result if with_erb

      YAML.safe_load(file_to_load) || {}
    end

    def plugin_dir(plugin_id = DEFAULT_PLUGIN_ID)
      if Gem.loaded_specs[plugin_id].nil?
        File.join Redmine::Plugin.directory, plugin_id
      else
        Gem.loaded_specs[plugin_id].full_gem_path
      end
    end

    def to_prepare(*args, &block)
      if Rails.version > '6.0'
        # INFO: https://www.redmine.org/issues/36245
        Rails.logger.info 'after_plugins_loaded hook should be used instead'
      else
        # ActiveSupport::Reloader.to_prepare(*args, &block)
        Rails.configuration.to_prepare(*args, &block)
      end
    end

    def persisting
      Additionals.debug 'Loading persisting...'
      yield
    end

    def after_initialize(&block)
      Additionals.debug 'After initialize...'
      Rails.application.config.after_initialize(&block)
    end

    def load_hooks!(plugin_id = DEFAULT_PLUGIN_ID)
      target = plugin_id.camelize.constantize
      target::Hooks
    end

    def deface_setup!
      Rails.application.paths['app/overrides'] ||= []
      Dir.glob(Rails.root.join('plugins/*/app/overrides')).each do |dir|
        Rails.application.paths['app/overrides'] << dir unless Rails.application.paths['app/overrides'].include? dir
      end
    end

    # required multiple times because of this bug: https://www.redmine.org/issues/33290
    def redmine_database_ready?(with_table = nil)
      ActiveRecord::Base.connection
    rescue ActiveRecord::NoDatabaseError
      false
    else
      with_table.nil? || ActiveRecord::Base.connection.table_exists?(with_table)
    end
  end

  def initialize(plugin_id: DEFAULT_PLUGIN_ID, debug: false)
    self.plugin_id = plugin_id
    self.debug = debug

    apply_reset
  end

  def apply_reset
    @patches = []
    @helpers = []
    @global_helpers = []
  end

  def plugin_dir
    @plugin_dir ||= self.class.plugin_dir plugin_id
  end

  # use_app: false => :plugin_dir/lib/:plugin_id directory
  def require_files(spec, use_app: false, reverse: false)
    dir = if use_app
            File.join plugin_dir, 'app', spec
          else
            File.join plugin_dir, 'lib', plugin_id, spec
          end

    files = Dir[dir].sort

    files.reverse! if reverse
    files.each { |f| require f }
  end

  def incompatible?(plugins = [])
    plugins.each do |plugin|
      raise "\n\033[31m#{plugin_id} plugin cannot be used with #{plugin} plugin.\033[0m" if Redmine::Plugin.installed? plugin
    end
  end

  def load_macros!
    require_files File.join('wiki_macros', '**/*_macro.rb')
  end

  def load_custom_field_format!(reverse: false)
    require_files File.join('custom_field_formats', '**/*_format.rb'),
                  reverse: reverse
  end

  def add_patch(patch)
    if patch.is_a? Array
      @patches += patch
    else
      @patches << patch
    end
  end

  def add_helper(helper)
    if helper.is_a? Array
      @helpers += helper
    else
      @helpers << helper
    end
  end

  def add_global_helper(helper)
    if helper.is_a? Array
      @global_helpers += helper
    else
      @global_helpers << helper
    end
  end

  def apply!
    validate_apply

    apply_patches!
    apply_helpers!
    apply_global_helpers!

    # reset patches and helpers
    apply_reset

    true
  end

  private

  def validate_apply
    return if @helpers.none? || @patches.none?

    controller_patches = @patches.select do |p|
      if p.is_a? String
        true unless p == p.chomp('Controller')
      else
        c = p[:target].to_s
        true unless c == c.chomp('Controller')
      end
    end

    @helpers.each do |h|
      helper_controller = if h.is_a? String
                            "#{h}Controller"
                          else
                            c = h[:controller]
                            if c.is_a? String
                              "#{c}Controller"
                            else
                              c.to_s
                            end
                          end

      if controller_patches.include? helper_controller
        raise ExistingControllerPatchForHelper, "Do not add helper to #{helper_controller} if patch exists (#{plugin_id})"
      end
    end
  end

  def apply_patches!
    patches = @patches.map do |p|
      if p.is_a? String
        { target: p.constantize, patch: p }
      else
        patch = p[:patch] || p[:target].to_s
        { target: p[:target], patch: patch }
      end
    end

    patches.uniq!
    Additionals.debug "patches for #{plugin_id}: #{patches.inspect}" if debug

    patches.each do |patch|
      patch_module = if patch[:patch].is_a? String
                       patch_dir = "#{plugin_dir}/lib/#{plugin_id}/patches"
                       require "#{patch_dir}/#{patch[:patch].underscore}_patch"
                       "#{plugin_id.camelize}::Patches::#{patch[:patch]}Patch".constantize
                     else
                       # if module specified (if not string), use it
                       patch[:patch]
                     end

      target = patch[:target]
      target.include patch_module unless target.included_modules.include? patch_module
    end
  end

  def apply_helpers!
    helpers = @helpers.map do |h|
      if h.is_a? String
        { controller: "#{h}Controller".constantize, helper: "#{plugin_id.camelize}#{h}Helper".constantize }
      else
        c = h[:controller].is_a?(String) ? "#{h[:controller]}Controller".constantize : h[:controller]
        helper = if h[:helper]
                   h[:helper]
                 else
                   helper_name = if h[:controller].is_a? String
                                   h[:controller]
                                 else
                                   h[:controller].to_s.chomp 'Controller'
                                 end
                   "#{plugin_id.camelize}#{helper_name}Helper".constantize
                 end
        { controller: c, helper: helper }
      end
    end

    helpers.uniq!
    Additionals.debug "helpers for #{plugin_id}: #{helpers.inspect}" if debug

    helpers.each do |h|
      target = h[:controller]
      target.send :helper, h[:helper]
    end
  end

  def apply_global_helpers!
    global_helpers = @global_helpers.uniq
    Additionals.debug "global helpers for #{plugin_id}: #{global_helpers.inspect}" if debug

    global_helpers.each do |h|
      ActionView::Base.include h
    end
  end
end
