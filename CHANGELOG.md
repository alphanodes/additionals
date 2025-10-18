# Changelog

## 4.3.0

- Redmine 6.0 support dropped
- Redmine 6.1 required
- Ruby 3.2 required

## 4.2.0

- mermaid 11.12.0 support
- improve compatibility with other plugins #182
- Ukrainian translation provided, thanks to Victor Вовк!
- sortable.js added

## 4.1.0

- fix deface checksum for admin/info
- mermaid 11.6.0 support
- fix bug with project dashboard, if only one single project exists

## 4.0.0

- Support for Redmine 6
- Redmine 5 support dropped
- Gemify support dropped
- switch icons from fontawesome to tabler
- broken tradingview macro removed
- latest Chart.js support (version 4.4.7)
- Chart.js Plugin datalabels 2.2.0
- Chart.js Plugin annotation 3.0.1
- moment 2.30.1 support
- mermaid 11.4.1 support
- gps macro has been added
- add options for link to video with youtube macro
- add options for link to video with vimeo macro
- attachment_link macro has been added

## 3.4.0

- Move assign to me button to assign to block
- svg icons support for Redmine 6
- remove tooltip css style, which overwrote default redmine style

## 3.3.2

- Maintenance release
- Ruby 3.1 required
- Working on Tabler icons integration

## 3.2.0

- add option to hide issue attachments, if number of file is too high
- add option to auto watch issues, which assigned to me
- rubocop offenses has been fixed
- D3 7.9.0 support

## 3.1.0

- Fix missing label for view all documents
- Ruby 3 required

## 3.0.9

- Chart.js Plugin annotation 2.1.2 support
- Chart.js Plugin matrix 2.0.1 support
- D3 7.8.5 support
- d3plus 2.0.3 support
- Show author badge with notes
- Allow fast edit of description for a issue

## 3.0.8

- Mermaid 9.3.0 support
- Chart.js Plugin matrix 1.3.0 support
- D3 7.8.0 support

## 3.0.7

- D3 7.6.1 support
- Mermaid 9.1.7 support
- moment 2.29.4 support
- d3plus 2.0.2 support
- Chart.js Plugin matrix 1.2.0 support
- Chart.js Plugin datalabels 2.1.0 support

## 3.0.6

- D3 7.4.5 support
- Remove issue autowatch (this feature comes with Redmine 5)
- Remove feature custom top menu items (this was unmaintained for a long time)
- Drop feature "remove help" from top menu
- Add project filter for new_issue_message type
- Mermaid 9.1.2 support
- Switch from gemoji to tanuki_emoji
- Chart.js 3 support
- Add Chart.js matrix plugin
- Fix scope of users for select2 in projects
- Updated clipboardJS to 2.0.11
- Fixed auto assign issue to group member, if issue can be assigned to a group

## 3.0.5.2

- Fix refresh bug for async blocks for query lists

## 3.0.5.1

- Fix refresh bug for async blocks if settings change

## 3.0.5

- Mermaid 8.14.0 support
- D3 7.3.0 support
- Updated clipboardJS to 2.0.10
- d3plus 2.0.1 support
- introduce hooks controller_additionals_assign_to_me_before_save, controller_additionals_assign_to_me_after_save (see #127)
- introduce hooks controller_additionals_change_status_before_save, controller_additionals_change_status_after_save (see #127)
- Fix multiple asynchronous block loads

## 3.0.4

- Mermaid 8.13.6 support
- D3 7.2.1 support
- Ruby 2.6 is required
- Use redmine_plugin_kit gem as loader
- Move settings rake tasks and true?/false? to redmine_plugin_kit
- fixed default dashboard order for system default for specific project
- add rake task "redmine:additionals:reset_recently_dashboards" to reset recently used dashboards

## 3.0.3

- Ruby 2.7 warnings fixed
- Mermaid 8.11.5 support
- D3 7.0.1 support
- Remove issue macro, which is now supported by Redmine core
- new ticket message can be overwritten for projects
- fixed scope of public project dashboards for all projects
- FontAwesome 5.15.4 support
- Adjust integration of macro button, because of changed Redmine source <https://www.redmine.org/issues/31887>

## 3.0.2

- d3plus to v2.0.0-alpha.30 support
- Mermaid 8.9.2 support
- Bug fix for select2 loading without named field
- FontAwesome 5.15.3 support
- D3 6.6.2 support
- Fix news limit for welcome dashboard block
- Frensh translation updated, thanks to Brice BEAUMESNIL!
- clipboard.js updated to v2.0.8
- Ruby 2.5 is required

## 3.0.1

- Do not show "Assign to me" if assigned_to is disabled for tracker
- FontAwesome 5.15.1 support
- D3 6.3.1 support
- Mermaid 8.8.4 support
- add current_user as special login name for user macro (which shows current login user)
- add text parameter to user macro (which disable link to user)
- add asynchronous text block
- gemify plugin to use it with Gemfile.local or other plugins
- remove spam protection functionality
- Chart.js 2.9.4 support
- Allow overwrite mermaid theme and variables

## 3.0.0

- Introduce dashboards
- Redmine 4.1 or newer is required
- FontAwesome 5.14.0 support
- D3 6.1.1 support
- Mermaid 8.8.0 support
- d3plus to v2.0.0-alpha.29 support
- drop wiki header and footer settings

## 2.0.24

- FontAwesome 5.13.0 support
- Mermaid 8.4.8 support
- clipboard.js updated to v2.0.6
- fix for spam protection with invisible_captcha
- D3 5.16.0 support
- Ruby 2.4 is required

## 2.0.23

- members macro now supports with_sum option
- FontAwesome 5.12 support
- FontAwesome ajax search has been added
- Mermaid 8.4.6 support
- D3 5.15.0 support
- Drop nvd3 library
- Drop Chartjs stacked100 library
- Drop d3plus-hierarchy library
- Drop calendar macro
- Support private comments with issue macro
- Google Docs macro has been added
- Fix bug with Rack 2.0.8 or newer
- Drop Redmine 3.4 support
- Add Redmine 4.1 support
- Use view_layouts_base_body_top hook, which is available since Redmine 3.4
- Refactoring new hooks (without template)
- asciinema.org macro has been added - thanks to @kotashiratsuka
- Select2 4.0.13 support

## 2.0.22

- FontAwesome 5.11.2 support
- Mermaid 8.4.2 support
- Select2 4.0.12 support
- Chart.js 2.9.3 support
- Chart.js Plugin datalabels 0.7.0 support
- d3plus to v2.0.0-alpha.25
- Fix user visibility for members macro
- Fix user visibility for issue reports
- Drop ZeroClipboard library

## 2.0.21

- fix mail notification if issue author changed
- fix permission bug for closed issues with freezed mode
- Ruby 2.2.x support has been dropped. Use 2.3.x or newer ruby verion
- FontAwesome 5.9.0 support
- remove issue_close_with_open_children functionality, because this is included in Redmine 3.4.x #47 (thanks to @pva)
- add hierarchy support for projects macro #45
- select2 support
- bootstrap-datepicker 1.9.0 support

## 2.0.20

- support single process rake installation #40
- FontAwesome 5.8.0 support

## 2.0.19

- mermaid 8.0.0 support
- FontAwesome 5.7.1 support
- fixed close issue without permission
- create correct journal entry if issue status changed from sidebar #37
- create correct journal entry if issue has been 'assigned to me' from sidebar

## 2.0.18

- Performance improvement (#36)
- FontAwesome 5.6.3 support
- Fix problem from migrating from Redmine 3.x to Redmine 4 with lost settings

## 2.0.17

- Fix bug with undefined constant for tags
- add possibility to use custom date with date macro
- FontAwesome 5.6.0 support

## 2.0.16

- CSS fix for project macro
- More compatibility for autocomplete_users with other plugins (like redmine_contacts_helpdesk)
- Compatibility to wiking plugin (macro list)
- Add Spanish translation, thanks to @dktcoding!
- Wiki button for available macros
- replace permission hide-in-memberbox with "hide" as role setting - check your roles, if you used this permission!
- replace multiple current_date macros with one macro called date
- cleanup macros: if no data exists, macros is displayed instead of data
  (before some macros used error messages other hide message at all)

## 2.0.15

- FontAwesome 5.5.0 support
- Usability improvement for change author in issue formular
- options and permission for issue requires timelog to use status
- New option to freeze issues on close. With permission "edit closed issue" user can break this rule.
- Fix problem with help menu and other redmine plugins (compatibility problem with other plugins)
- Fix problem with disabled users and changing author for issues

## 2.0.14

- Change status is now compatible with redmine_agile
- Do not show sidebar for changing status, if edit_closed_issues permission is missing
- FontAwesome 5.3.1 support
- compatibility with plugin redmine_sudo and redmine_base_deface
- FontAwesome wiki macro has been added (called fa)
- Redmine.org issue and wiki page macro has been added
- Show macro list to all logged users at /help/macros
- Help menu, with more links to Redmine help pages (which can be used with other plugins, to assign additional entries)

## 2.0.13

- FontAwesome 5.2.0 support
- smiley support for markdown text_formatting
- new_issue macro with i18n support
- updated bootstrap-datepicker to v1.8.0
- updated d3plus to v2.0.0-alpha.17
- ruby 2.2.0 is required
- Redmine 3.4 is required
- support sidebar with non default wiki titles (thanks to @danielvijge)

## 2.0.12

- Provide d3 loader function
- More robust code for dealing with finding data

## 2.0.11

- i18n methods
- FontAwesome 5.0.13 support

## 2.0.10

- Remove bootstrap library
- compatibility with <https://www.redmine.org/plugins/issue_id>
- bug fix: issue and user macro uses absolute url in mailer notification
- Updated marmaid library to version 8.0.0-rc8
- Updated d3 library to 3.5.17
- Updated nvd3 library to latest 1.8.6
- FontAwesome 5.0.12 support
- Set default values for ui-tooltip css class
- ZeroClipboard updated to 2.3.0

## 2.0.9

- Updated bootstrap library to 4.0.0
- Drop angular_gantt library
- enables deface overwrite directory for all installed plugins (not only additionals)
- Updated d3plus to version v2.0.0-alpha.16
- add "Assign to me" to issues
- add "Status on sidebar" for issues
- add link to create new issue on user profile
- FontAwesome 5.0.8 support
- Add marmaid library

## 2.0.8

- Provide XLSX helper (and drop XLS helper)
- FontAwesome 5.0.6 support
- add list support for rake task setting_set

## 2.0.7

- FontAwesome 5.0.2 support
- Switching to SLIM template engine

## 2.0.6

- add rake tasks: drop_settings, setting_get and setting_set
- Updated nvd3 library to 1.8.6
- Updated angularjs libraries to v2.0.0-rc.1
- Wiki iframe macro integration has been added

## 2.0.5

- Redmine 3.4 bug fixes
- Helper function fa_icon renamed to font_awesome_icon because of conflicts with redmine_bootstrap_kit
- Cleanups deface overwrites
- add hook for user show
- Traditional Chinese support has been added (thanks to @archonwang)
- Wiki macro for weather with meteoblue has been added
- Wiki macro for google maps has been added
- Wiki macro for issues now supports display a comment and detect issue id and comment id from URL

## 2.0.4

- Add group_users macro
- Fix bug with REST-API and assigned_id for issues
- Use user name setting for sort order in macros
- Add invisible_captcha spam protection on registration form

## 2.0.3

- Allow remove watchers without re-adding it (only if author or assigned_user changed)
- Fix sort order of users for change author
- Add uninstall documentation
- Add option to disable autowatch issue at user level
- Fixed bug with recurring_tasks plugin and autowatch issues
- Add more unit tests

## 2.0.2

- Add option to add involved issue users automatically
- Add change issue author feature
- Fixed bug with Redmine 3.4.x and default assignee settings
- Refactoring patch include and wiki macros

## 2.0.1

- Simplified Chinese support has been added (thanks to @archonwang)
- Helper function fa_icon has been added
- Help menu item and MyPage menu item does not require application server restart anymore
- Redmine 3.4.x compatibility

## 2.0.0

- Redmine Tweaks has been renamed to additionals, because to resolve loading order problem of Redmine plugins
- Merge common_libraries plugin into additionals plugin
- Fontawesome support
- Redmine 3.0.x required

## 1.0.3

- TradingView macro support
- CryptoCompare macro support
- Reddit macro support
- Twitter macro improved with prefix image

## 1.0.2

- Smiley/Emoji legacy support

## 1.0.1

- Coding standard cleanups
- ruby 2.1.5 required or newer
- version bump

## 1.0.0

- user group support for issue auto assign
- optimize deface overwrite path
- drop remove latest projects support (because Redmine 3.2 has dropped latest projects)
- add permission for log time on closed issues - make sure you adjust our permissions!
- code cleanups and bug fixes
- restructure settings
- wiki pdf settings has been added
- updated documentation

## 0.5.8

- Fixed top menu items permissions for anonymous and non member #29
- Fixed bug with overwriting application handler, which cases problem with other plugins
- Tweaks link added to admin menu
- replaced user macro with {{user}} syntax (old syntax user#id is not supported anymore)
- more formats for user macro and avatar support
- rename list_users to members
- rename list_projects to projects
- new documentation on <https://redmine-tweaks.readthedocs.io>
- updated bootstrap-datepicker and fixed zh locale problem
- html validation error has been fixed
- remove garfield support (because there is no image source server available)
- slideshare wiki macro has been added
- issue wiki macro has been added
- autoassign issue if no assignee is selected
- n+1 query optimization

## 0.5.7

- Custom source URL for Garfield source
- Wiki footer bug fixed with missing line break at the end of page
- date period support for calendar macro
- Code cleanups

## 0.5.6

- Redmine 3.2.x compatibility
- user macro has been added (user#1 or user:admin)
- recently_updated has been added
- lastupdated_by has been added
- lastupdated_at has been added
- calendar macro support
- NoReferrer support has been added
- system information uptime and uname have been added
- twitter macro support
- gist macro support
- vimeo macro support

## 0.5.5

- dependency with deface (used to overview views)
- fixed garfield caching macro problem
- you can add content to overview page now (top and bottom)
- some content and view optimization (removed wiki_sidebar compatibility problems with other Redmine plugins)
- Code cleanups and refactoring

## 0.5.4

- issue rule added for closing issue with open sub issues
- issue rule added for status change
- issue rule added for assigned_to change

## 0.5.3

- Redmine 3.0.x and 3.1.x supported
- "New issue" link with list_projects macro
- Parameter syntax changed for list_users and list_projects macros (sorry for that)

## 0.5.2

- "Edit closed issue" permission has been added
- Permissions supported for top menu items

## 0.5.1

- "Hide role in memberbox" has been added

## 0.5.0

- Redmine 2.6.x compatibility
- URL fixes
- Garfield macro has been added

## 0.4.9

- added overview text field
- fix style for "goto top"
- added macro overview help page
- fix compatibility problems with sidebar and other plugins

## 0.4.8

- added youtube macro
- project guide subject can be defined for project overview page

## 0.4.7

- added jump to top link
- top menu item configuration has been added
- footer configuration (e.g. for imprint url) has been added

## 0.4.6

- initialize plugins settings now works with other plugins

## 0.4.5

- option to remove help menu item
- Redmine 2.4.1 required

## 0.4.4

- installation error fixed
- description update for link handling
- help url now opens in new windows
- sidebar error has been fixed, if no wiki page already exist

## 0.4.3

- global gantt and calendar bug fix

## 0.4.2

- no requirements of Wiki extensions plugin anymore

## 0.4.1

- Fix problem with my page permission

## 0.4.0

- First public release
