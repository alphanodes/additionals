.. Additionals documentation master file, created by
   sphinx-quickstart on Sat Apr 23 16:31:21 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

.. _Redmine: https://www.redmine.org
.. _Ruby: https://www.ruby-lang.org
.. _Gemfile: https://github.com/alphanodes/additionals/blob/master/Gemfile

Welcome to Additionals Plugin for Redmine
=========================================

Additionals is a `Redmine`_ plugin for customizing Redmine, providing wiki macros and act as a library/function provider for other Redmine plugins.


* Documentation: https://additionals.readthedocs.io
* Redmine.org plugin page: https://www.redmine.org/plugins/additionals
* Github: https://github.com/alphanodes/additionals

.. image:: https://readthedocs.org/projects/additionals/badge/?version=latest
   :target: https://additionals.readthedocs.io/en/latest/?badge=latest
   :alt: Documentation Status

.. image:: https://github.com/AlphaNodes/additionals/workflows/Tests/badge.svg
   :target: https://github.com/AlphaNodes/additionals/actions?query=workflow%3ATests

.. image:: https://github.com/AlphaNodes/additionals/workflows/Run%20Linters/badge.svg
   :target: https://github.com/AlphaNodes/additionals/actions?query=workflow%3A%22Run+Linters%22

.. image:: https://img.shields.io/badge/rate%20at-redmine.org-blue.svg?style=flat
   :target: https://www.redmine.org/plugins/additionals
   :alt: Rate at redmine.org

Requirements
------------

+--------------------+-----------------------------------+
| `Redmine`_ version | >= 4.1.0                          |
+--------------------+-----------------------------------+
| `Ruby`_ version    | >= 2.5.0                          |
+--------------------+-----------------------------------+
| Database version   | MySQL >= 5.7 or PostgreSQL >= 9.6 |
+--------------------+-----------------------------------+

.. note:: If you use MySQL, make sure all database tables using the same storage engine (InnoDB is recommended) and character set (utf8mb4 is recommended).

.. note:: For more information use the official `Redmine install documentation <https://www.redmine.org/projects/redmine/wiki/RedmineInstall>`_


Installation
------------

Install ``additionals`` plugin for `Redmine`_.

.. code-block:: bash

  $ cd $REDMINE_ROOT
  $ git clone -b stable https://github.com/AlphaNodes/additionals.git plugins/additionals
  $ bundle install --without development test
  $ bundle exec rake redmine:plugins:migrate RAILS_ENV=production
  $
  $ # if you want to use smiley/emoji legacy support, you have to put emoji icons to
  $ # $REDMINE_ROOT/public/images/emoji
  $ # To obtain image files, run the gemoji extract command on macOS Sierra or later:
  $ bundle exec gemoji extract public/images/emoji
  $
  $ # if you to not have macOS, you can put these files manually to $REDMINE_ROOT/public/images/emoji
  $ # see https://github.com/github/gemoji for more infos

Restart your application server (apache with passenger, nginx with passenger, unicorn, puma, etc.) and ``Additionals`` is ready to use.

More information about installation of Redmine plugins, you can find in the official `Redmine plugin documentation <https://www.redmine.org/projects/redmine/wiki/Plugins>`_.


Update
------

Update ``additionals`` plugin for `Redmine`_.

.. code-block:: bash

  $ cd $REDMINE_ROOT/plugins/additionals
  $ git pull
  $ cd ../..
  $ bundle install --without development test
  $ bundle exec rake redmine:plugins:migrate RAILS_ENV=production

Restart your application server (apache with passenger, nginx with passenger, unicorn, puma, etc.) and ``Additionals`` is ready to use.


Uninstall
---------

Uninstall ``additionals`` plugin for `Redmine`_.

.. code-block:: bash

  $ cd $REDMINE_ROOT
  $ bundle exec rake redmine:plugins:migrate NAME=additionals VERSION=0 RAILS_ENV=production
  $ rm -rf plugins/additionals public/plugin_assets/additionals


Features
--------

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
  * issues
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
* option to remove "My page" and/or "Help" from top menu
* customize top menu items
* disable (hide) modules for projects
* open external urls in new window
* smiley/emoji legacy support
* anonymize referrer for external urls
* hide role in project memberbox
* change issue author
* add involved issue users as watcher automatically
* create issue on user profile
* "assign to me" link on issue
* change issue state on sidebar
* configurable issue rules

  * freeze closed issue
  * change assigned_to automatically, if issue status changes
  * assigned_to has changed, but status change is required, too


Developer features
------------------

As Redmine does not support asset pipeline, we need to install Javascript plugins as Redmine plugins to load them globally.

If no common files are used as library plugin, every plugin has to deliver the same files. And if more
than one version of a library is delivered with each Redmine plugin, there is a problem.

Therefore if developer uses this plugin for the provided libraries, everything works smoothly.
Don't worry, if you only need a subset of the provided libraries. If you do not load a library, it is not used.

It provides :

* `Chart.js 2.9.4 <https://www.chartjs.org/>`_
* `Chart.js Plugin colorschemes 0.4.0 <https://github.com/nagix/chartjs-plugin-colorschemes>`_
* `Chart.js Plugin datalabels 0.7.0 <https://github.com/chartjs/chartjs-plugin-datalabels>`_
* `clipboardJS 2.0.8 <https://clipboardjs.com/>`_
* `d3 6.7.0 <https://d3js.org/>`_
* `d3plus v2.0.0-alpha.30 <https://d3plus.org/>`_
* `FontAwesome 5.15.3 <https://fontawesome.com/>`_
* `mermaid 8.10.2 <https://github.com/knsv/mermaid/>`_
* `Select2 4.0.13 <https://select2.org/>`_

And a set of various Rails helper methods (see below).

It provides the following Rails helper methods :

Libraries assets loader
-----------------------

.. code-block:: ruby

  additionals_library_load(module_name)


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

Redmine Plugins, which are using ``additionals``
------------------------------------------------

* `additional_tags <https://github.com/AlphaNodes/additional_tags>`_
* `redmine_automation <https://alphanodes.com/redmine-automation>`_
* `redmine_db <https://alphanodes.com/redmine-db>`_
* `redmine_git_hosting <http://redmine-git-hosting.io/>`_
* `redmine_hedgedoc <https://github.com/AlphaNodes/redmine_hedgedoc>`_
* `redmine_hrm <https://alphanodes.com/redmine-hrm>`_
* `redmine_omniauth_saml <https://github.com/alexandermeindl/redmine_omniauth_saml>`_
* `redmine_passwords <https://alphanodes.com/redmine-passwords>`_
* `redmine_postgresql_search <https://github.com/AlphaNodes/redmine_postgresql_search>`_
* `redmine_privacy_terms <https://github.com/AlphaNodes/redmine_privacy_terms>`_
* `redmine_reporting <https://alphanodes.com/redmine-reporting>`_
* `redmine_sudo <https://github.com/AlphaNodes/redmine_sudo>`_

If you know other plugins, which are using ``additionals``, please let us know or create a `PR <https://github.com/alphanodes/additionals/pulls>`_.

Contact and Support
-------------------

I am glad about your feedback on the plugin, `pull requests <https://github.com/alphanodes/additionals/pulls>`_, `issues <https://github.com/alphanodes/additionals/issues>`_, whatever. Feel free to contact me for any questions.


.. toctree::
    :maxdepth: 2

    manual
    dashboards
    macros
    tasks
    new_feature
    changelog
