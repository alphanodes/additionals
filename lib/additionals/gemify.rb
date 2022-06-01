# frozen_string_literal: true

module Additionals
  class Gemify
    class << self
      # install emoji fallback assets from gem (without asset pipeline)
      def install_emoji_assets
        Additionals.debug 'install_emoji_assets'
        return Rails.logger.error 'TanukiEmoji class for emoji not found' unless defined? TanukiEmoji

        source_image_path = TanukiEmoji.images_path
        target_image_path = File.join Dir.pwd, 'public', Additionals::EMOJI_ASSERT_PATH

        begin
          FileUtils.mkdir_p target_image_path
        rescue StandardError => e
          raise "Could not create directory #{target_image_path}: " + e.message
        end

        Dir["#{source_image_path}/*"].each do |file|
          target = File.join target_image_path, file.gsub(source_image_path, '')
          FileUtils.cp file, target unless File.exist?(target) && FileUtils.identical?(file, target)
        rescue StandardError => e
          raise "Could not copy #{file} to #{target}: " + e.message
        end
      end

      # install assets from gem (without asset pipline)
      def install_assets(plugin_id = 'additionals')
        return unless Gem.loaded_specs[plugin_id]

        source = File.join Gem.loaded_specs[plugin_id].full_gem_path, 'assets'
        destination = File.join Dir.pwd, 'public', 'plugin_assets', plugin_id
        return unless File.directory? source

        source_files = Dir["#{source}/**/*"]
        source_dirs = source_files.select { |d| File.directory? d }
        source_files -= source_dirs

        unless source_files.empty?
          base_target_dir = File.join destination, File.dirname(source_files.first).gsub(source, '')
          begin
            FileUtils.mkdir_p base_target_dir
          rescue StandardError => e
            raise "Could not create directory #{base_target_dir}: " + e.message
          end
        end

        source_dirs.each do |dir|
          target_dir = File.join destination, dir.gsub(source, '')
          begin
            FileUtils.mkdir_p target_dir
          rescue StandardError => e
            raise "Could not create directory #{target_dir}: " + e.message
          end
        end

        source_files.each do |file|
          target = File.join destination, file.gsub(source, '')
          FileUtils.cp file, target unless File.exist?(target) && FileUtils.identical?(file, target)
        rescue StandardError => e
          raise "Could not copy #{file} to #{target}: " + e.message
        end
      end

      # Create text file to Redmine's plugins directory.
      # The purpose is telling plugins directory to users.
      def create_plugin_hint(plugin_id = 'additionals')
        plugins_dir = File.join Bundler.root, 'plugins'
        path = File.join plugins_dir, plugin_id
        return if File.exist? path

        File.write path,
                   "This plugin was installed as gem wrote to Gemfile.local instead of putting Redmine's plugin directory.\n" \
                   "See #{plugin_id} gem installed directory.\n"
      rescue Errno::EACCES => e
        Rails.logger.warn "Could not create plugin hint file: #{e.message}"
      end
    end
  end
end
