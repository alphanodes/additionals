# frozen_string_literal: true

module Additionals
  module Patches
    # Deface removes the compiled method of a template when an override for it is created,
    # so the next render picks the override up. It finds that method by matching the
    # template name anywhere in all methods of the view class - a helper named like the
    # template (ai_wiki_edit_button_data for wiki/edit) matched as well, and removing a
    # method the class only inherits raised NameError. In development that broke every
    # code reload: the reloader stopped halfway and left models without acts_as_positioned.
    #
    # Only compiled templates are considered here (Rails names them _<path>__<hash>_<id>),
    # and a method is removed where it is defined.
    module DefaceOverridePatch
      private

      def expire_compiled_template
        template_class = Deface.template_class
        method_name = compiled_template_method template_class, args[:virtual_path]
        return if method_name.nil? || method_name.match?(/\A_#{self.class.digest virtual_path: args[:virtual_path]}_/)

        template_class.instance_method(method_name).owner.send :remove_method, method_name
      end

      def compiled_template_method(template_class, virtual_path)
        pattern = /\A_\w*#{virtual_path.gsub(/[^a-z_]/, '_')}/
        template_class.instance_methods.detect { |name| name.match? pattern }
      end
    end
  end
end
