# frozen_string_literal: true

module Additionals
  module Patches
    module GravatarPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        # Redmine renders a gravatar without any dimension of its own: the size
        # only reaches the image url, and image_tag is called with :size removed
        # (lib/plugins/gravatar/lib/gravatar.rb). An avatar that fails to load -
        # gravatar.com unreachable, blocked or simply slow - therefore collapses
        # to nothing and the surrounding line jumps once the image arrives.
        #
        # Adding the size class core already uses for its initials avatars gives
        # the image its box from css instead, so it holds its place either way.
        # It is not patched into AvatarsHelper#avatar, because both redmine_hrm
        # and redmine_contacts_helpdesk wrap that one with alias_method.
        def gravatar(email, options = {})
          size_class = "s#{(options[:size] || GravatarHelper::DEFAULT_OPTIONS[:size]).to_i}"
          classes = options[:class].to_s.split
          classes.unshift size_class unless classes.include? size_class
          options[:class] = classes.join ' '

          super
        end
      end
    end
  end
end
