# frozen_string_literal: true

module IssuesShow
  # The attachments block this override replaces is not the same in every
  # redmine version: master passes the journals that added each attachment to
  # link_to_attachments, 7.0 does not, and that changes the hash deface
  # validates the anchor against.
  #
  # TODO(Redmine 7.1 release): once that change arrives in a stable release,
  # the branch no longer tells the two apart - the failing hash test says so.
  # Kept in a local variable: this file is evaluated more than once per boot,
  # and a constant would warn about being reinitialized every time.
  attachments_original = if Redmine::VERSION::BRANCH == 'devel'
                           'ae094e05b145f72c0128a6334a71f03562e6e8d1'
                         else
                           'e2a825486b3b1ba51c0e2fa1f72bdd5e98e1b964'
                         end

  Deface::Override.new virtual_path: 'issues/_action_menu',
                       name: 'additionals-issue-action-menu',
                       insert_after: 'erb[loud]:contains("watcher_link")',
                       original: 'a519feb931e157589bc506b2673abeef994aa96b',
                       partial: 'hooks/view_issue_action_menu'

  Deface::Override.new virtual_path: 'issues/_action_menu',
                       name: 'additionals-issue-action-dropdown',
                       insert_before: 'erb[loud]:contains("copy_object_url_link")',
                       original: 'cf959d0baa105476b364f7fe33b05516e27dda65',
                       partial: 'hooks/view_issue_action_dropdown'

  Deface::Override.new virtual_path: 'issues/tabs/_history',
                       name: 'additionals-issue-author-on-note',
                       insert_before: 'erb[loud]:contains("render_private_notes_indicator")',
                       original: '38ddc174974d0a0ee482dd73070ee80baebe9e4d',
                       partial: 'issues/additionals_note_history'

  Deface::Override.new virtual_path: 'issues/show',
                       name: 'additionals-issue-attachments',
                       replace: 'erb[silent]:contains("if @issue.attachments.any?")',
                       closing_selector: 'erb[silent]:contains("end")',
                       original: attachments_original,
                       partial: 'issues/hide_attachments'
end
