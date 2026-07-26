# frozen_string_literal: true

# Resolves and validates icon values for the Tabler sprite based icon picker.
#
# Stored values are plain Tabler sprite names (e.g. "car", "brand-gitlab",
# "matomo"). Legacy values with a fas_/far_/fab_ prefix ("fas_car") are
# translated to their tabler equivalent via the legacy map. Unknown values
# fall back to FALLBACK.
class AdditionalsIcon
  # Fallback tabler icon for values without a sensible mapping
  FALLBACK = 'point'

  # Sprite files (without extension): custom brand marks vs the main sprite
  CUSTOM_SPRITE = 'icons_custom'
  MAIN_SPRITE = 'icons'

  # A valid tabler sprite name: lowercase letters/digits, hyphen separated
  FORMAT_REGEXP = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  # A legacy value prefix (fas_, far_, fab_)
  LEGACY_REGEXP = /\Afa[rsb]_/

  class << self
    # Resolve any stored value to a renderable tabler sprite name.
    def resolve(value)
      name = value.to_s.strip
      return FALLBACK if name.blank?

      name = translate name if legacy? name
      return name if known? name

      # A bare legacy name without the fas_/far_/fab_ prefix (e.g. the
      # {{fa(file-alt)}} wiki macro) that is not itself a tabler name: try the
      # legacy map before giving up.
      mapped = mapping[name]
      known?(mapped) ? mapped : FALLBACK
    end

    # Whether the value is a legacy value (fas_/far_/fab_ prefix)
    def legacy?(value)
      value.to_s.match? LEGACY_REGEXP
    end

    # Translate a legacy fa value ("fas_car") to a tabler name via the map
    def translate(value)
      name = value.to_s.split('_', 2).last.to_s
      mapping.fetch name, FALLBACK
    end

    # Sprite file (without extension) that holds the given icon
    def sprite(name)
      custom_names.include?(name.to_s) ? CUSTOM_SPRITE : MAIN_SPRITE
    end

    # Whether the name renders from one of the additionals sprites
    def known?(name)
      name = name.to_s
      return false unless name.match? FORMAT_REGEXP

      sprite_names.include?(name) || custom_names.include?(name)
    end

    # Curated, sorted list of selectable icons for the picker
    def selectable
      @selectable ||= begin
        names = loader.yaml_config_load('tabler_picker_icons.yml').map(&:to_s)
        names.sort!
        names.freeze
      end
    end

    # Standalone inline <svg> markup for a name, with the sprite paths inlined
    # so it can be rasterized (e.g. drawn onto a canvas for a favicon). Colored
    # via stroke; returns nil for an unknown/empty symbol.
    def inline_svg(name, color: 'currentColor', size: 24, stroke_width: 2)
      inner = symbol_inner resolve(name)
      return if inner.blank?

      %(<svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}" ) +
        %(viewBox="0 0 24 24" fill="none" stroke="#{color}" stroke-width="#{stroke_width}" ) +
        %(stroke-linecap="round" stroke-linejoin="round">#{inner}</svg>)
    end

    # Reset memoized data (used by tests)
    def reset!
      @mapping = @sprite_names = @custom_names = @selectable = @sprite_files = nil
    end

    private

    # Inner markup (paths) of a sprite <symbol>, or nil when not found
    def symbol_inner(name)
      content = sprite_file sprite(name)
      match = content.match %r{<symbol[^>]*id="icon--#{Regexp.escape name}"[^>]*>(.*?)</symbol>}m
      match && match[1].strip
    end

    def sprite_file(file)
      @sprite_files ||= {}
      @sprite_files[file] ||= File.read File.join(loader.plugin_dir, 'assets', 'images', "#{file}.svg")
    end

    def mapping
      @mapping ||= loader.yaml_config_load('fontawesome_tabler_map.yml').freeze
    end

    def sprite_names
      @sprite_names ||= loader.yaml_config_load('icon_source.yml').to_set { |entry| entry['name'] }
    end

    def custom_names
      @custom_names ||= File.read(File.join(loader.plugin_dir, 'assets', 'images', "#{CUSTOM_SPRITE}.svg"))
                            .scan(/id="icon--([a-z0-9-]+)"/).flatten.to_set
    end

    def loader
      @loader ||= RedminePluginKit::Loader.new plugin_id: 'additionals'
    end
  end
end
