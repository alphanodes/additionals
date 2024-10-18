# frozen_string_literal: true

class AdditionalsChart
  include ActiveRecord::Sanitization
  include Redmine::I18n

  attr_accessor :project, :query, :data_values

  CHART_DEFAULT_HEIGHT = 350
  CHART_DEFAULT_WIDTH = 400

  def initialize(project: nil, query: nil)
    self.project = project
    self.query = query
    self.data_values = {}

    query.project = project if query && project
  end

  def color_schema
    AdditionalsPlugin.active_reporting? ? RedmineReporting.setting(:chart_color_schema) : 'tableau.Classic20'
  end

  def data
    raise 'overwrite it!'
  end

  # build return value
  def build_chart_data(datasets, **options)
    cached_labels = labels

    data = { datasets: datasets.to_json,
             labels: cached_labels.keys,
             label_ids: cached_labels.values }

    required_labels = options.key?(:required_labels) ? options.delete(:required_labels) : 2

    data[:valid] = cached_labels.any? && cached_labels.count >= required_labels unless options.key? :valid
    data[:width] = CHART_DEFAULT_WIDTH unless options.key? :width
    data[:height] = CHART_DEFAULT_HEIGHT unless options.key? :height
    data[:value_link_method] = '_project_issues_path' unless options.key? :value_link_method
    data[:color_schema] = color_schema

    values = Array(datasets).first[:data]
    data[:data_sum] = values.present? ? values.sum : 0

    data.merge options
  end

  private

  def build_values_without_gaps(data, gap_value = 0)
    values = []
    labels.each_key do |label|
      values << if data.key? label
                  data[label]
                else
                  gap_value
                end
    end

    values
  end

  def init_labels
    @labels = {}
  end

  def labels
    # NOTE: do not sort it, because color changes if user switch language
    @labels.to_h
  end

  def add_label(label, id)
    return if @labels.key? label

    @labels[label] = id
  end
end
