# Welcome to Additionals Plugin for Redmine

Additionals is a `Redmine` plugin for customizing Redmine, providing wiki macros and act as a library/function provider for other Redmine plugins.

* Redmine.org plugin page: <https://www.redmine.org/plugins/additionals>
* Github: <https://github.com/alphanodes/additionals>

[![Rate at redmine.org](https://img.shields.io/badge/rate%20at-redmine.org-blue.svg?style=flat)](https://www.redmine.org/plugins/additionals) [![Run Linters](https://github.com/AlphaNodes/additionals/workflows/Run%20Linters/badge.svg)](https://github.com/AlphaNodes/additionals/actions?query=workflow%3A%22Run+Linters%22) [![Run Tests](https://github.com/AlphaNodes/additionals/workflows/Tests/badge.svg)](https://github.com/AlphaNodes/additionals/actions?query=workflow%3ATests)

## Requirements

| Name               | requirement                      |
| -------------------|----------------------------------|
| `Redmine` version  | >= 5.0                           |
| `Ruby` version     | >= 2.7                           |
| Database version   | MySQL >= 8.0 or PostgreSQL >= 10 |

.. note::
   If you use MySQL, make sure all database tables using the same storage engine (InnoDB is recommended) and character set (utf8mb4 is recommended).

.. note::
   For more information use the official [Redmine install documentation](https://www.redmine.org/projects/redmine/wiki/RedmineInstall)

## Installation

Install `additionals` plugin for `Redmine`.

```shell
  cd $REDMINE_ROOT
  git clone -b stable https://github.com/AlphaNodes/additionals.git plugins/additionals
  bundle config set --local without 'development test'
  bundle install
  bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Restart your application server (apache with passenger, nginx with passenger, unicorn, puma, etc.) and *Additionals* is ready to use.

More information about installation of Redmine plugins, you can find in the official [Redmine plugin documentation](https://www.redmine.org/projects/redmine/wiki/Plugins>).

## Update

Update *additionals* plugin.

```shell
  cd $REDMINE_ROOT/plugins/additionals
  git pull
  cd ../..
  bundle install
  bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Restart your application server (apache with passenger, nginx with passenger, unicorn, puma, etc.) and `additionals` is ready to use.

## Uninstall

Uninstall `additionals` plugin.

```shell
  cd $REDMINE_ROOT
  bundle exec rake redmine:plugins:migrate NAME=additionals VERSION=0 RAILS_ENV=production
  rm -rf plugins/additionals public/plugin_assets/additionals
```

## Features

* Dashboard (Drag&Drop) Support
* Text for login page
* Global footer for all projects
* Welcome text for login page
* Global sidebar content support
* Note for new issues above issue content (e.g. for guidelines)
* PDF for wiki pages
* Wiki macros for:

  * asciinema
  * cryptocompare
  * date
  * fa
  * gihub gist
  * google_docs
  * gmap
  * group_users
  * iframe
  * last_updated_at
  * last_updated_by
  * members
  * meteoblue
  * new_issue
  * projects
  * recently_updated
  * reddit
  * redmine.org issue and wiki page (redmine_issue and reminde_wiki)
  * slideshare
  * tradingview
  * twitter
  * user
  * vimeo
  * youtube

* macro list with all available macros at /help/macros
* macro button for wiki toolbar with available macros with project and permission context support
* option to remove "Help" from top menu
* disable (hide) modules for projects
* open external urls in new window
* smiley/emoji legacy support
* anonymize referrer for external urls
* hide role in project memberbox
* change issue author
* create issue on user profile
* "assign to me" link on issue
* change issue state on sidebar
* configurable issue rules

  * freeze closed issue
  * change assigned_to automatically, if issue status changes
  * assigned_to has changed, but status change is required, too

## Developer features

As Redmine does not support asset pipeline, we need to install Javascript plugins as Redmine plugins to load them globally.

If no common files are used as library plugin, every plugin has to deliver the same files. And if more
than one version of a library is delivered with each Redmine plugin, there is a problem.

Therefore if developer uses this plugin for the provided libraries, everything works smoothly.
Don't worry, if you only need a subset of the provided libraries. If you do not load a library, it is not used.

It provides :

* [Chart.js Plugin colorschemes 0.4.0 (patched for chartjs 3)](https://github.com/nagix/chartjs-plugin-colorschemes)
* [Chart.js Plugin datalabels 2.0.0](https://github.com/chartjs/chartjs-plugin-datalabels)
* [Chart.js Plugin matrix 1.1.1](https://github.com/kurkle/chartjs-chart-matrix)
* [clipboardJS 2.0.10](https://clipboardjs.com/)
* [d3 7.4.4](https://d3js.org/)
* [d3plus 2.0.1](https://d3plus.org/)
* [FontAwesome 5.15.4](https://fontawesome.com/)
* [mermaid 9.0.1](https://github.com/mermaid-js/mermaid)
* [moment 2.29.2](https://github.com/moment/moment) (used by Chart.js)
* [Select2 4.0.13](https://select2.org/)

And a set of various Rails helper methods (see below).

It provides the following Rails helper methods :

## Libraries assets loader

```ruby
   additionals_library_load(module_name)
```

This method loads all JS and CSS files needed by the required module.

The following modules are available :

* chartjs
* chartjs_colorschemes
* chartjs_datalabels
* clipboardjs
* d3
* d3plus
* font_awesome
* mermaid
* select2

### Redmine Plugins, which are using *`additionals*

* [additional_tags](https://github.com/AlphaNodes/additional_tags)
* [redmine_automation](https://alphanodes.com/redmine-automation)
* [redmine_db](https://alphanodes.com/redmine-db)
* [redmine_git_hosting](http://redmine-git-hosting.io/)
* [redmine_hedgedoc](https://github.com/AlphaNodes/redmine_hedgedoc)
* [redmine_hrm](https://alphanodes.com/redmine-hrm>)
* [redmine_omniauth_saml](https://github.com/AlphaNodes/redmine_saml)
* [redmine_passwords](https://alphanodes.com/redmine-passwords)
* [redmine_issue_view_columns](https://github.com/AlphaNodes/redmine_issue_view_columns)
* [redmine_privacy_terms](https://github.com/AlphaNodes/redmine_privacy_terms)
* [redmine_reporting](https://alphanodes.com/redmine-reporting)
* [redmine_servicedesk](https://alphanodes.com/redmine-servicedesk)
* [redmine_sudo](https://github.com/AlphaNodes/redmine_sudo)

If you know other plugins, which are using *additionals*, please let us know or create a [PR](https://github.com/alphanodes/additionals/pulls).

## You need a feature

*additionals* is [Open-source](https://opensource.org/osd) and it is available at <https://github.com/alphanodes/additionals>

If you want to implement new features in it or if you want to change something, you can provide a pull request.

The plugin is maintained by [AlphaNodes](https://alphanodes.com) for free as far as possible. In case you want a feature, which is not available and you are not capable of implementing it yourself, you can request this feature from AlphaNodes.

We are an `Open-source`_ company from Munich and we are usually getting payed for our time we spent on development. As we know our plugin at its best we are glad to take this job from you. In case the requested plugin changes still
fit to the plugin purpose. Please, contact us in case you are interested in plugin development.

## Contact and Support

I am glad about your feedback on the plugin, [pull requests](https://github.com/alphanodes/additionals/pulls), [issues](https://github.com/alphanodes/additionals/issues), whatever. Feel free to contact me for any questions.
