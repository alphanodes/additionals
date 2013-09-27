# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013  AlphaNodes GmbH

module RedmineTweaksHelper

  def redmine_tweaks_settings_tabs
    [ {:name => 'general', :partial => 'settings/redmine_tweaks_general', :label => :label_settings_general},
      {:name => 'content', :partial => 'settings/redmine_tweaks_content', :label => :label_settings_content}
    ]
  end

end