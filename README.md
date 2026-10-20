# Additionals Plugin for Redmine

`additionals` customizes Redmine with dashboards, wiki macros, issue rules and a global search, and is the shared library for other Redmine plugins.

* Redmine.org plugin page: <https://www.redmine.org/plugins/additionals>
* GitHub: <https://github.com/alphanodes/additionals>

[![Rate at redmine.org](https://img.shields.io/badge/rate%20at-redmine.org-blue.svg?style=flat)](https://www.redmine.org/plugins/additionals) [![Run Linters](../../actions/workflows/linters.yml/badge.svg)](../../actions/workflows/linters.yml) [![Run Tests](../../actions/workflows/tests.yml/badge.svg)](../../actions/workflows/tests.yml) [![Vitest](../../actions/workflows/vitest.yml/badge.svg)](../../actions/workflows/vitest.yml)

## Features

* **Dashboards** for the home page and project overviews, arranged by drag and drop, private, shared or per role
* **Global search** dialog (Cmd+K or Ctrl+K) on all pages
* **Wiki macros**, e.g. for videos, maps, icons, members, projects and recently updated pages, with a macro button in the wiki toolbar
* **Issue rules**: freeze closed issues, assign automatically on status changes, require logged time for selected statuses
* **Issue shortcuts**: _Assign to me_, status change in the sidebar, fast edit of the description, new issue from a user profile, linked categories
* **Note for new issues**, global and per project
* **Global contents**: text on the login page, global sidebar, footer and wiki sidebar
* **Hidden roles** in member boxes and lists, auto-watch of issues assigned to you, change of the issue author
* **Help menu** with links to the documentation of Redmine and installed plugins
* PDF options for wiki pages, emoji and legacy smiley support, hiding of project modules

The [manual](docs/manual.md) describes all functions and settings.

> **Note:** We reserve the right to remove functions again, e.g. when Redmine itself provides them or they conflict with it.

## Requirements

| Name             | Requirement                                       |
| ---------------- | ------------------------------------------------- |
| Redmine          | >= 7.0.2                                          |
| Ruby             | >= 3.3                                            |
| Database         | MySQL >= 8.4, MariaDB >= 11.8 or PostgreSQL >= 16 |

Only MySQL (including MariaDB) and PostgreSQL are supported. The plugin refuses to load on SQLite or MSSQL, although Redmine supports them.

With MySQL or MariaDB, all tables must use the same storage engine (InnoDB recommended) and character set (utf8mb4 recommended). With mixed engines, migrations that add foreign keys to a `MyISAM` table fail with a misleading `does not match column ... type` error.

## Installation

```shell
cd $REDMINE_ROOT
git clone -b stable https://github.com/alphanodes/additionals.git plugins/additionals
bundle config set --local without 'development test'
bundle install
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Restart the application server afterwards. More about plugins in the [Redmine plugin documentation](https://www.redmine.org/projects/redmine/wiki/Plugins).

### Update

```shell
cd $REDMINE_ROOT/plugins/additionals
git pull
cd ../..
bundle install
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Restart the application server afterwards.

### Uninstall

```shell
cd $REDMINE_ROOT
bundle exec rake redmine:plugins:migrate NAME=additionals VERSION=0 RAILS_ENV=production
rm -rf plugins/additionals
```

Uninstall all plugins that depend on `additionals` first.

## For Plugin Developers

`additionals` gives plugins a common base, so they do not ship and load the same libraries in different versions.

### Libraries

| Library | Version |
| ------- | ------- |
| [Chart.js](https://github.com/chartjs/Chart.js) | 4.5.1 |
| [Chart.js plugin annotation](https://github.com/chartjs/chartjs-plugin-annotation) | 3.1.0 |
| [Chart.js plugin colorschemes](https://github.com/nagix/chartjs-plugin-colorschemes) (patched for Chart.js 3+) | 0.4.0 |
| [Chart.js plugin datalabels](https://github.com/chartjs/chartjs-plugin-datalabels) | 2.2.0 |
| [Chart.js chart matrix](https://github.com/kurkle/chartjs-chart-matrix) | 3.0.0 |
| [d3plus](https://d3plus.org/) | 4.7.0 |
| [dhtmlxGantt](https://dhtmlx.com/docs/products/dhtmlxGantt/) | 9.1.4 |
| [mermaid](https://github.com/mermaid-js/mermaid) | 12.2.0 |
| [Select2](https://select2.org/) | 4.0.13 |
| [Sortable](https://github.com/SortableJS/Sortable) | 1.15.7 |

Pages and dashboard blocks load only the libraries they need, each file once per page:

```ruby
additionals_library_load :chartjs_meta
```

The [Library Loader](docs/libraries.md) lists all library names and describes loading in dashboard blocks and on demand in the browser, and how plugins register libraries of their own.

### Development guides

* [Dashboard Development Guide](docs/dashboards.md): dashboard blocks and dashboard types
* [Library Loader](docs/libraries.md): JavaScript and CSS libraries for pages and blocks
* [Chart Development Guide](docs/charts.md): charts in blocks and pages
* [Settings Schema](docs/settings-schema.md): declared settings for blocks and queries
* [Updating mermaid](docs/updating-mermaid.md)

### Plugins using additionals

* [additional_tags](https://github.com/alphanodes/additional_tags)
* [redmine_ai](https://alphanodes.com/redmine-ai)
* [redmine_automation](https://alphanodes.com/redmine-automation)
* [redmine_clamav](https://alphanodes.com/redmine-clamav)
* [redmine_db](https://alphanodes.com/redmine-db)
* [redmine_devops](https://alphanodes.com/redmine-devops)
* [redmine_gantt](https://alphanodes.com/redmine-gantt)
* [redmine_git_hosting](https://github.com/redmine-git-hosting/redmine_git_hosting)
* [redmine_hedgedoc](https://github.com/alphanodes/redmine_hedgedoc)
* [redmine_hrm](https://alphanodes.com/redmine-hrm)
* [redmine_issue_checklists](https://alphanodes.com/redmine-issue-checklists)
* [redmine_issue_view_columns](https://github.com/alphanodes/redmine_issue_view_columns)
* [redmine_passwords](https://alphanodes.com/redmine-passwords)
* [redmine_privacy_terms](https://github.com/alphanodes/redmine_privacy_terms)
* [redmine_reporting](https://alphanodes.com/redmine-reporting)
* [redmine_saml](https://alphanodes.com/redmine-saml)
* [redmine_servicedesk](https://alphanodes.com/redmine-servicedesk)
* [redmine_sudo](https://github.com/alphanodes/redmine_sudo)
* [redmine_templates](https://alphanodes.com/redmine-templates)
* [redmine_timesheet](https://alphanodes.com/redmine-timesheet)
* [redmine_wiki_guide](https://alphanodes.com/redmine-wiki-guide)

You know another plugin using `additionals`? Let us know or open a [pull request](https://github.com/alphanodes/additionals/pulls).

## Contributing

Pull requests with fixes and features are welcome. Please use the [issue tracker](https://github.com/alphanodes/additionals/issues) for questions and feedback. All contributions are licensed under the terms of GNU/GPL v2.

`additionals` is maintained by [AlphaNodes](https://alphanodes.com), an open source service company from Munich. If you need a feature you cannot implement yourself, AlphaNodes offers commercial plugin development, as long as the feature fits the purpose of the plugin.

## License

This plugin is licensed under the terms of GNU/GPL v2, see [LICENSE](LICENSE).

`additionals` is an extension for Redmine, Copyright (C) 2006- Jean-Philippe Lang, a flexible project management web application written using the Ruby on Rails framework. More details on <https://www.redmine.org>.

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

## Credits

* [Tabler Icons](https://tabler.io/icons), Copyright (c) 2020- Paweł Kuna, MIT License
* [mermaid](https://github.com/mermaid-js/mermaid/blob/develop/LICENSE), includes code from DOMPurify, licensed under the Mozilla Public License 2.0 and the Apache License 2.0
