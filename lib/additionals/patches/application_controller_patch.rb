module Additionals
  module Patches
    module ApplicationControllerPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :user_setup_without_additionals, :user_setup
          alias_method :user_setup, :user_setup_with_additionals

          helper :additionals_menu
          helper :additionals_fontawesome

          include AdditionalsMenuHelper
          include AdditionalsFontawesomeHelper
          include ActionView::Helpers::TagHelper
          include ActionView::Helpers::UrlHelper
        end
      end

      module InstanceMethods
        def user_setup_with_additionals
          user_setup_without_additionals
          return unless User.current.try(:hrm_user_type_id).nil?

          if Additionals.setting?(:remove_mypage)
            Redmine::MenuManager.map(:top_menu).delete(:my_page) if Redmine::MenuManager.map(:top_menu).exists?(:my_page)
          else
            handle_top_menu_item(:my_page, url: my_path, after: :home, if: proc { User.current.logged? })
          end

          if Additionals.setting?(:remove_help)
            Redmine::MenuManager.map(:top_menu).delete(:help) if Redmine::MenuManager.map(:top_menu).exists?(:help)
          else
            handle_top_menu_item(:help, url: '#', symbol: 'fas_question', last: true)
            @additionals_help_items = additionals_help_menu_items
          end
        end
      end
    end
  end
end
