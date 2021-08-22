# frozen_string_literal: true

class AdditionalsImport < Import
  class_attribute :import_class

  # Returns the objects that were imported
  def saved_objects
    object_ids = saved_items.pluck :obj_id
    import_class.where(id: object_ids).order(:id)
  end

  def project=(project)
    settings['project'] = project
  end

  def project
    settings['project']
  end

  def mappable_custom_fields
    object = import_class.new
    @custom_fields = object.custom_field_values.map(&:custom_field)
  end

  def build_custom_field_attributes(object, row)
    object.custom_field_values.each_with_object({}) do |v, h|
      value = case v.custom_field.field_format
              when 'date'
                row_date row, "cf_#{v.custom_field.id}"
              else
                row_value row, "cf_#{v.custom_field.id}"
              end
      next unless value

      h[v.custom_field.id.to_s] =
        if value.is_a? Array
          value.map { |val| v.custom_field.value_from_keyword val.strip, object }.flatten!&.compact
        else
          v.custom_field.value_from_keyword value, object
        end
    end
  end
end
