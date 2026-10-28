# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DeletionBlockersTest < Additionals::TestCase
  include Redmine::I18n

  # Issue categories stand in for an entry other records refer to: issues by an
  # integer column, a custom field value by the id as a string
  class Category < IssueCategory
    include Additionals::Concerns::DeletionBlockers

    add_deletion_blocker :issues,
                         label: :label_issue_plural,
                         scope: -> { Issue },
                         column: :category_id,
                         projects: ->(references) { references.pluck :project_id }
    add_deletion_blocker :custom_values, label: :label_custom_field_plural, scope: -> { custom_values_of_formats 'string' }, column: :value
  end

  def setup
    prepare_tests
    set_language_if_valid 'en'
    field = IssueCustomField.create! name: 'Category reference', field_format: 'string'
    @referenced_by_field = Category.find issue_categories(:issue_categories_003).id
    CustomValue.create! customized: issues(:issues_001), custom_field: field, value: @referenced_by_field.id.to_s
  end

  def test_destroy_is_blocked_while_the_entry_is_in_use
    category = Category.find issue_categories(:issue_categories_001).id

    # the issues keep their category, the dependent nullify did not run
    assert_no_difference ['IssueCategory.count', "Issue.where(category_id: #{category.id}).count"] do
      assert_not category.destroy
    end
    assert_equal ['Printing cannot be deleted while it is still in use: Issues (3)'], category.errors.full_messages
    assert_equal [1], category.reference_project_ids
  end

  def test_destroy_of_an_entry_nothing_refers_to
    category = Category.find issue_categories(:issue_categories_004).id

    assert_not category.deletion_blocked?
    assert category.destroy
  end

  def test_destroy_along_with_the_owner
    category = Category.find issue_categories(:issue_categories_001).id
    category.destroyed_by_association = Project.reflect_on_association :issue_categories

    assert category.destroy
  end

  def test_blockers_of_several_entries
    ids = Category.where(id: [1, 2, 3, 4]).ids

    assert_sorted_equal [1, 3], Category.with_deletion_blockers.ids & ids
    assert_equal({ 1 => { issues: 3 }, 3 => { custom_values: 1 } }, Category.deletion_blocker_counts(ids))

    entries = Category.where(id: [1, 2, 3]).to_a
    Category.load_deletion_blockers entries

    assert_equal ['Issues (3)', '', 'Custom fields (1)'], entries.map(&:deletion_blocked_by)
  end

  def test_without_blockers_no_entry_is_blocked
    assert_empty Class.new(IssueCategory) { include Additionals::Concerns::DeletionBlockers }.with_deletion_blockers
  end
end
