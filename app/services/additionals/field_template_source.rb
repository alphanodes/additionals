# frozen_string_literal: true

module Additionals
  # What a FieldTemplate may know about a kind of record beyond its custom
  # fields: the attributes it offers as placeholders and how they read.
  #
  # One kind of record may have several templates which allow different
  # placeholders (a short name and a longer line of a list, for example) - each
  # of them is a source of its own over the same record type.
  #
  # Names are passed in downcase, the template matches them case
  # insensitively.
  class FieldTemplateSource
    # The placeholders allowed in this template, as name and label. The label
    # is a locale key or plain text where redmine has none.
    def placeholders
      {}
    end

    # Every name which does not mean a custom field, allowed here or not. A
    # name which is reserved but not allowed is refused instead of being taken
    # for a custom field of the same name.
    def reserved_placeholders
      placeholders
    end

    # The custom fields a placeholder may name, by name or by cf_ID
    def custom_fields
      []
    end

    # The printed value of an attribute: a string, or an array of strings
    def attribute_value(_record, name)
      raise NotImplementedError, "#{self.class.name} does not resolve #{name}"
    end

    # The value a condition compares with. Differs from the printed one where
    # that changes with the language of the reader, a status for example.
    def condition_value(record, name)
      attribute_value record, name
    end

    # false where an attribute is turned off for this kind of record: it then
    # prints nothing instead of whatever it held before.
    def placeholder_enabled?(_name)
      true
    end

    # false for a custom field the reader may not see. It prints nothing and
    # counts as empty in a condition, so a template written by someone who
    # sees it still works for everyone else without telling what it holds.
    def field_readable?(_field)
      true
    end

    # The label of a referenced record, where it is known by something else
    # than its name. nil leaves it to the template.
    def readable(_value)
      nil
    end
  end
end
