module Additionals
  module Patches
    module ApplicationControllerPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :user_setup, :additionals
        end
      end

      module InstanceMethods
        def user_setup_with_additionals
          user_setup_without_additionals
          return unless User.current.try(:hrm_user_manager).nil?
          additionals_menu_item_delete(:help)
          unless Additionals.settings[:remove_help].to_i == 1
            custom_url = Additionals.settings[:custom_help_url]
            if custom_url.present?
              additionals_menu_item_add(:help, custom_url)
            else
              additionals_menu_item_add(:help)
            end
          end

          if Additionals.settings[:remove_mypage].to_i == 1
            additionals_menu_item_delete(:my_page)
          else
            additionals_menu_item_add(:my_page)
          end
        end

        def additionals_menu_item_delete(item)
          Redmine::MenuManager.map(:top_menu).delete(item) if Redmine::MenuManager.map(:top_menu).exists?(item)
        end

        def additionals_menu_item_add(item, custom_url = nil)
          return if Redmine::MenuManager.map(:top_menu).exists?(item)

          case item
          when :help
            url = if custom_url.present?
                    custom_url
                  else
                    Redmine::Info.help_url
                  end
            Redmine::MenuManager.map(:top_menu).push :help, url, html: { class: 'external' }, last: true
          when :my_page
            Redmine::MenuManager.map(:top_menu).push :my_page,
                                                     { controller: 'my', action: 'page' },
                                                     after: :home,
                                                     if: proc { User.current.logged? }
          else
            raise 'unknow top menu item'
          end
        end
      end
    end
  end
end
