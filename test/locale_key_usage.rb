# frozen_string_literal: true

require 'yaml'

module Additionals
  # Which locale keys a plugin's code asks for and which ones it can resolve on
  # its own. Plain Ruby without Rails: the plugin conventions test uses it, and
  # so does a standalone check over all plugins of an instance.
  module LocaleKeyUsage
    KEY = '[A-Za-z][A-Za-z0-9_]*'
    # Quoted keys may address a nested node (I18n.t 'activerecord.errors.messages.blank')
    DOTTED_KEY = "#{KEY}(?:\\.[A-Za-z0-9_]+)*".freeze
    # A quoted key ends right at the quote, so an interpolated "label_#{x}" never matches
    QUOTED = %(:?'(#{DOTTED_KEY})'|:?"(#{DOTTED_KEY})").freeze
    PATTERNS = [/\bl\s*\(?\s*(?::(#{KEY})\b|#{QUOTED})/,
                # Rails' translate: I18n.t and the view helper t; t('.key') is a
                # lazy lookup relative to the view and is never matched
                /(?:\bI18n\.|(?<![\w.@$:]))t\s*\(?\s*(?::(#{KEY})\b|#{QUOTED})/,
                /\bflash_msg\s*\(?\s*:(#{KEY})\b/,
                # deferred translation; demands an underscore because "title:"
                # is also ActiveRecord ordering (title: :asc)
                /\b(?:label|caption|title):\s*:([A-Za-z][A-Za-z0-9]*_#{KEY})\b/,
                # a symbol in an array literal (the admin info checklist does that)
                /\[\s*:((?:label|text|notice|error|button|field)_[A-Za-z0-9_]+)\s*,/].freeze
    # flash_msg maps these onto fixed keys internally, every other symbol IS the key
    FLASH_MSG_ACTIONS = %w[create update delete save_error delete_error].freeze
    COMMENT_LINE = %r{\A\s*(?:\#|<%\#|/(?!\S))}
    SOURCE_DIRS = %w[app lib config].freeze
    SOURCE_EXTENSIONS = %w[.rb .rake .slim .erb].freeze
    # redmine_automation loads these out of every plugin, so code there may use its locales
    AUTOMATION_DIRS = %w[automation_rules automation_rule_actions automation_rule_conditions
                         automation_variable_filters automation_variable_list_providers
                         automation_health_checks fixed_automation_rules].freeze

    # Rails ships its own locales (errors.format comes from activemodel)
    FRAMEWORK_GEMS = %w[activesupport activemodel activerecord actionview].freeze

    module_function

    # Keys every plugin can rely on: Redmine core and the Rails frameworks
    def core_locale_keys(redmine_root)
      paths = [File.join(redmine_root, 'config/locales/en.yml')]
      FRAMEWORK_GEMS.each do |name|
        gem_dir = Gem::Specification.find_by_name(name).gem_dir
        paths.concat Dir[File.join(gem_dir, 'lib', '**', 'locale', 'en.yml')]
      rescue Gem::MissingSpecError
        next
      end
      paths.sum(Set.new) { |path| locale_keys_of path }
    end

    # Flat keys plus intermediate nodes: pluralisation blocks such as
    # "seconds: {one:, other:}" are addressed as `l :seconds`. Leaves below
    # activerecord.* count under their bare name too, they are reached through
    # the scope argument.
    def locale_keys_of(path)
      return Set.new unless File.exist? path

      data = YAML.safe_load_file path, permitted_classes: [Symbol], aliases: true
      root = data.is_a?(Hash) ? data.values.first : nil
      return Set.new unless root.is_a? Hash

      keys = Set.new
      walk = lambda do |node, prefix|
        node.each do |key, value|
          keys << "#{prefix}#{key}"
          keys << key if prefix.start_with?('activerecord.') && !value.is_a?(Hash)
          walk.call value, "#{prefix}#{key}." if value.is_a? Hash
        end
      end
      walk.call root, ''
      keys
    rescue StandardError
      Set.new
    end

    # Used keys with the files (relative to directory) that use them
    def used_locale_keys(directory)
      used = Hash.new { |hash, key| hash[key] = [] }
      source_files(directory).each do |file|
        relative = file.delete_prefix "#{directory}/"
        locale_keys_in_source(File.read(file, encoding: 'UTF-8', invalid: :replace)).each do |key|
          used[key] << relative
        end
      end
      used
    end

    def source_files(directory)
      files = SOURCE_DIRS.flat_map { |sub| Dir[File.join(directory, sub, '**', '*')] }
      files << File.join(directory, 'init.rb')
      files.select { |file| File.file?(file) && SOURCE_EXTENSIONS.include?(File.extname(file)) }
    end

    def locale_keys_in_source(source)
      keys = Set.new
      source.each_line do |line|
        # a key named in a comment is not a usage, and a scope: argument makes
        # the real key a path we cannot rebuild here
        next if line.match?(COMMENT_LINE) || line.include?('scope:')

        PATTERNS.each do |pattern|
          line.scan pattern do |groups|
            key = groups.compact.first
            keys << key unless FLASH_MSG_ACTIONS.include? key
          end
        end
      end
      keys
    end

    def automation_owned?(relative_path)
      parts = relative_path.split '/'
      parts.first == 'lib' && AUTOMATION_DIRS.include?(parts[1])
    end

    # Both declaration places, resolved transitively - see "Pflicht-Abhängigkeiten
    # stehen an zwei Stellen" in the central CLAUDE.md. Only plugins present in
    # plugins_dir count.
    def required_plugin_ids(plugins_dir, plugin, seen = Set.new)
      directory = File.join plugins_dir, plugin
      found = Set['additionals']
      Dir[File.join(directory, 'lib', '*.rb')].each do |file|
        list = File.read(file)[/REQUIRED_ALPHANODES_PLUGINS\s*=\s*%w\[([^\]]*)\]/m, 1]
        found.merge list.split if list
      end
      init = File.join directory, 'init.rb'
      found.merge File.read(init).scan(/requires_redmine_plugin\s+:([a-z_]+)/).flatten if File.exist? init

      found.each do |dep|
        next if seen.include?(dep) || !File.exist?(File.join(plugins_dir, dep, 'init.rb'))

        seen << dep
        required_plugin_ids plugins_dir, dep, seen
      end
      seen
    end
  end
end
