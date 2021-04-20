# frozen_string_literal: true

# This file is a part of redmine_db,
# a Redmine plugin to manage custom database entries.
#
# Copyright (c) 2016-2021 AlphaNodes GmbH
# https://alphanodes.com

class QueryRelationsColumn < QueryColumn
  # NOTE: used for CSV and PDF export
  def value_object(object)
    (object.send name).map(&:name).join "#{Query.additional_csv_separator} "
  end
end
