# frozen_string_literal: true

module Additionals
  module Patches
    module RolePatch
      extend ActiveSupport::Concern

      included do
        safe_attributes 'hide'
      end
    end
  end
end
