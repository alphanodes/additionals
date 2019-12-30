module Additionals
  module Patches
    module AutoCompletesControllerPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
      end

      module InstanceMethods
        def fontawesome
          icons = AdditionalsFontAwesome.search_for_select(params[:q].to_s.strip,
                                                           params[:selected].to_s.strip)
          icons.sort! { |x, y| x[:text] <=> y[:text] }

          respond_to do |format|
            format.js { render json: icons }
            format.html { render json: icons }
          end
        end
      end
    end
  end
end
