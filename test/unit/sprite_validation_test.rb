# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Validates that every literal icon name passed to `svg_icon_tag` or `sprite_icon`
# in plugin source files resolves to an existing `<symbol id="icon--..."/>` in the
# expected sprite file.
#
# Routing rules (matching the current refactor):
#   - svg_icon_tag('foo')                            -> additionals icons.svg
#   - svg_icon_tag('foo', plugin: '')                -> Redmine core icons.svg
#   - svg_icon_tag('foo', plugin: 'name')            -> plugins/<name>/assets/images/icons.svg
#   - svg_icon_tag('foo', sprite: 'icons_custom')    -> additionals icons_custom.svg
#   - sprite_icon('foo')                             -> Redmine core icons.svg (default plugin: nil)
#   - sprite_icon('foo', plugin: 'name')             -> plugins/<name>/assets/images/icons.svg
#
# Calls with non-literal first argument (e.g. `svg_icon_tag(icon_name, ...)`) are skipped
# - they cannot be statically validated.
class SpriteValidationTest < Additionals::TestCase
  PLUGINS_ROOT = Rails.root.join('plugins').freeze
  CORE_SPRITE  = Rails.root.join('app/assets/images/icons.svg').freeze
  CALL_REGEX = /\b(svg_icon_tag|sprite_icon)\b\s*\(?\s*['"]([\w-]+)['"]/m

  def setup
    @sprite_cache = {}
  end

  def test_all_literal_icon_calls_resolve_to_existing_symbols
    issues = []

    Dir.glob(PLUGINS_ROOT.join('*/{app,lib}/**/*.{rb,slim,erb}')).each do |path|
      next if path.include? '/test/'

      content = File.read path
      content.scan CALL_REGEX do
        match_data = Regexp.last_match
        method = match_data[1]
        icon_name = match_data[2]
        # Limit window so kwargs of the next call cannot leak in. Boundary = position
        # of the next svg_icon_tag/sprite_icon (or end of file), capped at 300 chars.
        next_call_pos = content.index(/\b(?:svg_icon_tag|sprite_icon)\b/, match_data.end(0))
        boundary = next_call_pos || content.length
        window_size = [boundary - match_data.begin(0), 300].min
        context_window = content[match_data.begin(0), window_size]

        sprite_path = resolve_sprite_path method, context_window, path
        next unless sprite_path # unknown plugin sprite -> skip silently

        unless sprite_has_id? sprite_path, icon_name
          line = line_number_at content, match_data.begin(0)
          issues << "  #{path}:#{line}: #{method} '#{icon_name}' -> #{sprite_path.relative_path_from Rails.root}"
        end
      end
    end

    assert_empty issues, "Icon references resolve to missing sprite symbols:\n#{issues.join "\n"}"
  end

  private

  # Returns the absolute Pathname of the sprite the call should resolve in,
  # or `nil` when the target plugin has no sprite (skip).
  def resolve_sprite_path(method, context_window, source_path)
    plugin_match = context_window.match(/plugin:\s*['"]([^'"]*)['"]/)
    sprite_match = context_window.match(/sprite:\s*['"]([\w-]+)['"]/)
    sprite_name = sprite_match ? sprite_match[1] : 'icons'

    if plugin_match
      plugin_value = plugin_match[1]
      return CORE_SPRITE if plugin_value.empty?

      plugin_sprite_path PLUGINS_ROOT.join(plugin_value), sprite_name
    elsif method == 'svg_icon_tag'
      # No `plugin:` kwarg
      # svg_icon_tag default: plugin: 'additionals'
      plugin_sprite_path PLUGINS_ROOT.join('additionals'), sprite_name
    else
      # sprite_icon default: plugin: nil -> core
      # (custom sprite without plugin would resolve in own plugin's sprite, but no callers do that)
      plugin_for_path = plugin_for_source source_path
      if sprite_match && plugin_for_path
        plugin_sprite_path PLUGINS_ROOT.join(plugin_for_path), sprite_name
      else
        CORE_SPRITE
      end
    end
  end

  def plugin_sprite_path(plugin_dir, sprite_name)
    candidate = plugin_dir.join 'assets/images', "#{sprite_name}.svg"
    candidate.exist? ? candidate : nil
  end

  def plugin_for_source(source_path)
    rel = Pathname.new(source_path).relative_path_from(PLUGINS_ROOT).to_s
    rel.split('/').first
  rescue ArgumentError
    nil
  end

  def sprite_has_id?(sprite_path, icon_name)
    @sprite_cache[sprite_path] ||= File.read(sprite_path).scan(/id="icon--([^"]+)"/).flatten.to_set
    @sprite_cache[sprite_path].include? icon_name
  end

  def line_number_at(content, position)
    content[0, position].count("\n") + 1
  end
end
