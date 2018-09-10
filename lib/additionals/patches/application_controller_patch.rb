module Additionals
  module Patches
    module ApplicationControllerPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :user_setup_without_additionals, :user_setup
          alias_method :user_setup, :user_setup_with_additionals
        end
      end

      module InstanceMethods
        def user_setup_with_additionals
          user_setup_without_additionals
          return unless User.current.try(:hrm_user_type_id).nil?

          additionals_menu_item_delete(:help)
          unless Additionals.setting?(:remove_help)
            custom_url = Additionals.settings[:custom_help_url]
            if custom_url.present?
              additionals_menu_item_add(:help, custom_url)
            else
              additionals_menu_item_add(:help)
            end
          end

          if Additionals.setting?(:remove_mypage)
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
            url = custom_url.presence || Redmine::Info.help_url
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
