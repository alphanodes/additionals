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
  end
end
