# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013,2014  AlphaNodes GmbH

module RedmineTweaks

    module IssuePatch
      def new_ticket_message
        @new_ticket_message = ''
        @new_ticket_message << Setting.plugin_redmine_tweaks['new_ticket_message']
      end
    end

end