# frozen_string_literal: true

module DashboardBlocks
  class IssueQueryBlock < QueryListBlock
    block_id 'issuequery'
    label { I18n.t :label_query_with_name, value: I18n.t(:label_issue_plural) }
    permission :view_issues
    query_block label: :label_issue_plural,
                list_partial: 'issues/list',
                class: IssueQuery,
                link_helper: '_project_issues_path',
                count_method: 'issue_count',
                entries_method: 'issues',
                entities_var: :issues,
                with_project: true
  end
end
