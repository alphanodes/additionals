# frozen_string_literal: true

module Additionals
  # Finds code of a plugin that talks to the library behind the select fields
  # of additionals (Select2, next Tom Select) instead of going through
  # additionals: calls of the library, its events and CSS classes, and the
  # helpers and names additionals had for it before. Only additionals may know the library, so an update or a switch of
  # the library stays a change in additionals. Plain Ruby without Rails, like
  # LocaleKeyUsage.
  module SelectLibraryUsage
    FILES = '{init.rb,{app,lib,config,assets/javascripts,assets/stylesheets,test}/**/*.{rb,rake,slim,erb,haml,js,mjs,cjs,jsx,css,scss}}'
    # Bundled libraries are not ours to change
    IGNORED_FILES = %r{(\A|/)(vendor|node_modules)/|\.min\.js\z}

    PATTERNS = {
      'call or jQuery event of the library' => /\.select2(?![\w-])/,
      'event of the library' => /\bselect2:\w/,
      'CSS class of the library' => /\bselect2-[a-z]/,
      'data of the library' => /[(\[]\s*['"]select2['"]\s*[)\]]/,
      'call or class of the library' => /\bTomSelect\b|\.tomselect\b|\bts-(wrapper|control|dropdown|dropdown-content|hidden-accessible)\b/,
      'former helper of additionals' => /\b(additionals_select2_tag|additionals_transform_to_select2|additionals_icon_loader|
                                            select2Tag|initSelect2|fixScopedTags|select2Filters|setSelect2Filter|
                                            buildSelect2Options|formatStateWith\w+|formatSelectionWithEmails|
                                            formatNameWithIcon|formatIconOption|formatColorScheme|
                                            additionals_field_formats|additionals_filter_urls)\b|
                                            library_load[\s(]+:select2\b/x
    }.freeze

    class << self
      # "file:line: reason" for each line of +directory+ with a match
      def hits(directory)
        Dir.glob(FILES, base: directory).grep_v(IGNORED_FILES).sort!.flat_map do |file|
          hits_in File.join(directory, file), file
        end
      end

      private

      def hits_in(path, file)
        File.foreach(path).with_index(1).filter_map do |line, number|
          reason = PATTERNS.find { |_, pattern| line.match? pattern }&.first
          "#{file}:#{number}: #{reason}" if reason
        end
      end
    end
  end
end
