# frozen_string_literal: true

module Additionals
  module Patches
    module GravatarPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        # Core gives a gravatar its width and height attributes
        # (https://www.redmine.org/issues/44645), but not the size class it uses
        # for initials avatars. The .avatar.sNN rules of core and the plugins
        # size an avatar by that class, so without it a gravatar would follow
        # its attributes alone wherever those rules differ from them.
        # It patches gravatar rather than AvatarsHelper#avatar so that it also
        # covers the calls that do not go through the avatar helper.
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
