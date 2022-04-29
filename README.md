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

> **_NOTE:_** If you use MySQL, make sure all database tables using the same storage engine (InnoDB is recommended) and character set (utf8mb4 is recommended).

> **_NOTE:_** For more information use the official [Redmine install documentation](https://www.redmine.org/projects/redmine/wiki/RedmineInstall)

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

* macro list with all available macros at /help/macros included documentation
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

### Redmine Plugins, which are using *additionals*

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

We are an `Open-source`_ service company from Munich. Among other things, we offer commercial plugin development (e.g. implementation function request, expansion of functionality, etc).  As we know our plugin at its best we are glad to take this job from you. In case the requested plugin changes still fit to the plugin purpose. Please, contact us in case you are interested in commercial plugin development.

## Additionals plugin manual

The plugin configuration takes place in the administration area by a user with administration permission. Go to *Plugins / Additionals* to open it.

The additionals plugin configuration is divided into several sections, described below.

## General section

The general section tab allows you to define some special behaviours for your Redmine installation.

### Contents

The following plugin options are available to be edited by users with administration rights in the area **Contents**:

- Text for login page
  - This section is for a short information on the login page below the login mask. For example who to contact in order to get Redmine access.

- Global sidebar
  - Place your global information here, if needed. Use wiki links or available macros that can be seen by every one.

- Project wide footer
  - In case you want to put some information about your company or for your imprint. Here you can also use wiki syntax for structuring your text.


### Settings

And the following options can be edited by users with administratios rights in the area **Settings**:

- Open external URLs
  - Activate the option ``Open external URLs`` in order to open those URLs in a new window or browser tab if someone wants to visit them.

- Go to top Link
  - Add "Go to top" link. If you have a lot of long pages, it is enabling users to easily return to the top of a page.

- Legacy smileys support
  - Activate the ``Legacy smileys support`` if you want to use the manual smiley code in your text (e.g. ``:)``). If you already use a plugin that supports Smileys this option should stay deactivated. For more info on Emoji-Browser support read [more here](http://caniemoji.com/). Have a look at the Emoji [cheat sheet](https://www.webpagefx.com/tools/emoji-cheat-sheet) for available Emoji-Codes.

- Disable modules
  - This feature will hide the selected modules in the project settings. Even if the module is enabled for use in the admin area it can not be selected by the project manager within the projects. Please note, if these modules already activated in existing projects, you will have to change and re-save the respective project settings first.


> **_NOTE:_**  Please restart the application server, if you make changes to the external urls settings as well as if you activate the Smileys support.

> **_Tip:_**  You can use the following manual smiley codes: :), =), :D, =D, :'(, :(, ;), :P, :O, :/, :S, :|, :X, :*, O:), >:), B), (!), (?), (v), (x) and  (/)


## Wiki section

If you click on this tab you get to the area, where users with administration rights can customize contents and settings for your Wiki pages in Redmine.

### Contents

Global wiki sidebar        
* Here you can implement useful macros like a display of your page hierarchy. But remember - only people with the correspondent rights will get a display of the content.
* You can also implement useful macros in this section. For example to implement some date or author macros (e.g. last_updated_at, last_updated_by)


> **_NOTE:_**  Use simple text, macros and wiki syntax for your content.

### PDF Wiki settings

- Remove Wiki title from PDF view   
  * When activated the general Wiki title info in the page header of the PDF view will not be displayed.

- Remove attachments from PDF view   
  * When activated the attachments will not be displayed in the PDF view of a Wiki page.


## Macros section

Redmine macros can be used in the Wiki of a project or in the text area of an issue. For more information on how to add macros use the Redmine help documentation.

The *Macros section* of the additionals plugin lists all available macros that the logged in user can use with the *macro button* of the wiki toolbar. If you leave them deactivated they are all available to your users for selection.

Macros marked here are not offered for selection. This allows you to limit the scope of the list for a better usability.

![Macro settings!](contrib/images/macro-settings.png "Macro settings")

If all macros are deactivated the *Macro button* of the Wiki toolbar will disappear.

> **_NOTE:_**  If you deactivate some macros here this does not mean the user may not implement them. All available macros of installed plugins will work even if they are not part of the macro button. The macro button is just a little helper for Redmine users with no macro experience to make it easier for them to use macros or to remember them.


### Macro button for Wiki toolbar

Many plugins are equipped with a number of useful macros. Unfortunately it is difficult for the normal user to find out which macros are usable without a look at the plugin documentation.

With the macro button for the Wiki toolbar we want to simplify the implementation of macros for users somehow and above all also promote. Because the use of macros belongs to the daily tools of the trade when dealing with the Wiki.

![Macro button!](contrib/images/additionals-makro-button.png "Macro button")

Figure: The Wiki toolbar macro button is a useful helper in order to select available project macros for your content.

The macro button for the Wiki toolbar is acessible for every user of a project. For reasons of clarity, the list of available macros is restricted according to the following criteria.

A user can see in the macro list:

* the macros that can be used for the respective area. Macros that only work in the wiki are not available in the issue area and vice versa.
* The macros, which he / she can use due to his / her role and the associated rights in the respective project.
* only the macros of modules activated in the project. Macros for deactivated functions are hidden in the list.

The function is easy to use. Just click the button with the left mouse. The dropdown list shows all your available macros. Select the one you want to use. The selected macro will be pasted to the cursor position. All you have to do is adapt missing parameters (if needed).







## Contact and Support

For questions or feedback on the plugin functions, [pull requests](https://github.com/alphanodes/additionals/pulls), [issues](https://github.com/alphanodes/additionals/issues) use only the issue system as a communication channel. Thank you.