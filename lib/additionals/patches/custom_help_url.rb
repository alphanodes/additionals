require_dependency 'redmine/info'

# Create namespace module for override
module Additionals
  module Patches
    module CustomHelpUrl
      # TODO: needs a restart of Redmine after custom_help_url setting value change
      # Override core Redmine::Info.help_url, when
      # Setting.plugin_redmine_custom_help_url['custom_help_url'] contains
      # a value otherwise fall back to core Redmine::Info.help_url value
      module Redmine
        module Info
          class << self
            def help_url
              url = Setting.plugin_additionals[:custom_help_url]
              url = 'https://www.redmine.org/guide' if url.blank?
              url
            end
          end
        end
      end
    end
  end
end

# Now include the namespace module into Redmine::Info module
unless Redmine::Info.included_modules.include? Additionals::Patches::CustomHelpUrl::Redmine::Info
  Redmine::Info.send(:include, Additionals::Patches::CustomHelpUrl::Redmine::Info)
end
