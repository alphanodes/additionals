# frozen_string_literal: true

module Additionals
  module Hooks
    class ModelHook < Redmine::Hook::Listener
      def after_plugins_loaded(_context = {})
        Additionals.setup!
      end

      def model_project_copy_before_save(context = {})
        source = context[:source_project]
        destination = context[:destination_project]
        return if source.blank? || destination.blank?

        copy_project_dashboards source, destination
      end

      private

      def copy_project_dashboards(source, destination)
        excluded_attrs = %w[id project_id created_at updated_at options]

        source.dashboards
              .where(dashboard_type: DashboardContentProject::TYPE_NAME)
              .find_each do |source_dashboard|
          dashboard = Dashboard.new
          dashboard.attributes = source_dashboard.attributes.dup.except(*excluded_attrs)
          dashboard.project = destination
          dashboard.layout = source_dashboard.layout.deep_dup if source_dashboard.layout.present?
          dashboard.layout_settings = source_dashboard.layout_settings.deep_dup if source_dashboard.layout_settings.present?
          dashboard.role_ids = source_dashboard.role_ids.dup if source_dashboard.visibility == Dashboard::VISIBILITY_ROLES
          dashboard.save!
        end
      end
    end
  end
end
