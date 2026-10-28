# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DeletionBlockersTest < Additionals::TestCase
  include Redmine::I18n

  # Issue categories stand in for an entry other records refer to: issues by an
  # integer column, custom field values by the id as a string
  class Category < IssueCategory
    include Additionals::Concerns::DeletionBlockers

    add_deletion_blocker :issues,
                         label: :label_issue_plural,
                         scope: -> { Issue },
                         column: :category_id,
                         projects: ->(references) { references.pluck :project_id }
    add_deletion_blocker :custom_values,
                         label: :label_custom_field_plural,
                         scope: -> { custom_values_of_formats 'string' },
                         column: :value,
                         projects: ->(references) { projects_of_custom_values references }
  end

  class CategoryQuery < Query
    include Additionals::Concerns::Query

    self.queried_class = Category
  end

  def setup
    prepare_tests
    set_language_if_valid 'en'
    @in_use = category :issue_categories_001
    @used_by_fields = category :issue_categories_003
    @unused = category :issue_categories_004

    value = @used_by_fields.id.to_s
    CustomValue.create! customized: issues(:issues_004), custom_field: IssueCustomField.create!(name: 'Category', field_format: 'string'),
                        value: value
    CustomValue.create! customized: users(:users_002), custom_field: UserCustomField.create!(name: 'Category', field_format: 'string'),
                        value: value
  end

  def test_destroy_is_blocked_while_the_entry_is_in_use
    # the issues keep their category, the dependent nullify did not run
    assert_no_difference ['IssueCategory.count', "Issue.where(category_id: #{@in_use.id}).count"] do
      assert_not @in_use.destroy
    end
    assert_equal ['Printing cannot be deleted while it is still in use: Issues (3)'], @in_use.errors.full_messages
  end

  def test_destroy_of_an_entry_nothing_refers_to
    assert_not @unused.deletion_blocked?
    assert @unused.destroy
  end

  def test_destroy_along_with_the_owner
    @in_use.destroyed_by_association = Project.reflect_on_association :issue_categories

    assert @in_use.destroy

    @used_by_fields.deleted_with_owner = true

    assert @used_by_fields.destroy
  end

  def test_blockers_of_several_entries
    entries = [@in_use, @used_by_fields, @unused]

    assert_equal({ @in_use.id => { issues: 3 }, @used_by_fields.id => { custom_values: 2 } },
                 Category.deletion_blocker_counts(entries.map(&:id)))

    Category.load_deletion_blockers entries

    assert_equal ['Issues (3)', 'Custom fields (2)', ''], entries.map(&:deletion_blocked_by)
  end

  # The issue names its project, the user none
  def test_reference_project_ids
    assert_equal [projects(:projects_001).id], @in_use.reference_project_ids
    assert_equal [projects(:projects_002).id], @used_by_fields.reference_project_ids
  end

  def test_filter_deletable
    ids = [@in_use, @used_by_fields, @unused].map(&:id)
    query = CategoryQuery.new

    { ['=', ['1']] => [@unused],
      ['!', ['0']] => [@unused],
      ['=', ['0']] => [@in_use, @used_by_fields],
      ['!', ['1']] => [@in_use, @used_by_fields],
      ['=', %w[0 1]] => [@in_use, @used_by_fields, @unused],
      ['!', %w[0 1]] => [] }.each do |(operator, values), expected|
      found = Category.where(id: ids).where(query.sql_for_deletable_field('deletable', operator, values)).ids

      assert_sorted_equal expected.map(&:id), found, "#{operator} #{values}"
    end
  end

  def test_without_blockers_no_entry_is_blocked
    assert_empty Class.new(IssueCategory) { include Additionals::Concerns::DeletionBlockers }.with_deletion_blockers
  end

  private

  def category(name)
    Category.find issue_categories(name).id
  end
end
