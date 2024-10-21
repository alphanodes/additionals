# frozen_string_literal: true

module Additionals
  module Patches
    module ApplicationControllerPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods
        before_action :enable_smileys
      end

      module InstanceMethods
        def render_flash_mail(mail, name = nil)
          content = "#{name} <span class=\"icon icon-email\">#{mail}</span>"
          return content if name.blank?

          "#{name} #{content}"
        end

        def flash_msg(msg, value: nil, code: nil, mail: nil, obj: nil, field: :id)
          return msg unless msg.is_a? Symbol

          skip_field_info = false

          message = case msg
                    when :save_error
                      if obj.present? && obj.errors.full_messages.present?
                        skip_field_info = true
                        l :notice_save_error_with_messages, errors: obj.errors.full_messages.to_comma_list
                      else
                        l :notice_unsuccessful_save
                      end
                    when :delete_error
                      if obj.present? && obj.errors.full_messages.present?
                        skip_field_info = true
                        l :notice_delete_error_with_messages, errors: obj.errors.full_messages.to_comma_list
                      else
                        l :notice_unsuccessful_delete
                      end
                    when :create
                      l :notice_successful_create
                    when :update
                      l :notice_successful_update
                    when :delete
                      l :notice_successful_delete
                    else
                      if mail.present?
                        l msg, render_flash_mail(mail)
                      elsif value.present?
                        l msg, value
                      elsif code.present?
                        l msg, "<em>#{value}</em>"
                      else
                        l msg
                      end
                    end

          message << " (#{obj.send field})" if !skip_field_info && obj

          message
        end

        def enable_smileys
          return if !Additionals.setting?(:legacy_smiley_support) ||
                    Redmine::WikiFormatting::Textile::Formatter::RULES.include?(:inline_smileys)

          Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_smileys
        end
      end
    end
  end
end
