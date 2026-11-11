# frozen_string_literal: true

module Additionals
  module Patches
    module ApplicationControllerPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        before_action :enable_smileys
        helper_method :additionals_select_fields?
        helper :additionals_js_heads
        helper :additionals_render_async
        helper :additionals_remote_form
      end

      module InstanceMethods
        # Whether the page uses select fields of additionals. Pages for people
        # without access to Redmine (e.g. public pages of a plugin) answer
        # false: they register no query filters and load no library for them.
        def additionals_select_fields?
          true
        end

        # The address alone, with a name "Name (address)". Plain text, flash_msg
        # escapes it.
        def render_flash_mail(mail, name = nil)
          name.present? ? "#{name} (#{mail})" : mail.to_s
        end

        def flash_msg(msg, value: nil, code: nil, mail: nil, obj: nil, field: :id)
          return msg unless msg.is_a? Symbol

          skip_field_info = false

          # Core renders flash messages as HTML, and values, mail addresses and
          # error messages may contain user input, so they are escaped
          message = case msg
                    when :save_error
                      if obj.present? && obj.errors.full_messages.present?
                        skip_field_info = true
                        l :notice_save_error_with_messages, errors: flash_escape(obj.errors.full_messages.to_comma_list)
                      else
                        l :notice_unsuccessful_save
                      end
                    when :delete_error
                      if obj.present? && obj.errors.full_messages.present?
                        skip_field_info = true
                        l :notice_delete_error_with_messages, errors: flash_escape(obj.errors.full_messages.to_comma_list)
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
                        l msg, flash_escape(render_flash_mail(mail))
                      elsif value.present?
                        l msg, flash_escape(value)
                      elsif code.present?
                        l msg, "<em>#{flash_escape code}</em>"
                      else
                        l msg
                      end
                    end

          message << " (#{flash_escape obj.send(field)})" if !skip_field_info && obj

          message
        end

        def enable_smileys
          rules_class = Additionals.textile_rules_class
          return if !Additionals.setting?(:legacy_smiley_support) ||
                    rules_class::RULES.include?(:inline_smileys)

          rules_class::RULES << :inline_smileys
        end

        private

        def flash_escape(text)
          ERB::Util.html_escape(text.to_s).to_str
        end
      end
    end
  end
end
