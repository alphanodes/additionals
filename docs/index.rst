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

This plugin is the successor of `Redmine Tweaks <https://github.com/alphanodes/redmine_tweaks>`_


* Documentation: https://additionals.readthedocs.io
* Redmine.org plugin page: https://www.redmine.org/plugins/additionals
* Github: https://github.com/alphanodes/additionals

.. image:: https://readthedocs.org/projects/additionals/badge/?version=latest
   :target: https://additionals.readthedocs.io/en/latest/?badge=latest
   :alt: Documentation Status

.. image:: https://api.codeclimate.com/v1/badges/d92c0bda57f80e7c76b7/maintainability
   :target: https://codeclimate.com/github/AlphaNodes/additionals/maintainability
   :alt: Maintainability

.. image:: https://travis-ci.org/AlphaNodes/additionals.svg?branch=master
   :target: https://travis-ci.org/AlphaNodes/additionals

.. image:: https://img.shields.io/badge/rate%20at-redmine.org-blue.svg?style=flat
   :target: https://www.redmine.org/plugins/additionals
   :alt: Rate at redmine.org

Requirements
------------

+--------------------+----------------------+
| `Redmine`_ version | >= 3.4.0             |
+--------------------+----------------------+
| `Ruby`_ version    | >= 2.3.0             |
+--------------------+----------------------+
| Gem packages       | see `Gemfile`_       |
+--------------------+----------------------+


Installation
------------

Install ``additionals`` plugin for `Redmine`_.

.. code-block:: bash

  $ cd $REDMINE_ROOT
  $ git clone -b v2-stable git://github.com/alphanodes/additionals.git plugins/additionals
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

* use "Project guide" on project overview page
* global header for all projects
* global footer for all projects
* welcome text for login page
* global sidebar content support
* set info message above new ticket (e.g. for guidelines)
* wiki macros for:

  * cryptocompare
  * date
  * fa
  * gihub gist
  * gmap
  * group_users
  * iframe
  * issues
  * members
  * meteoblue
  * new_issue
  * projects
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
* spam protection on registration form
* add involved issue users as watcher automatically
* create issue on user profile
* "assign to me" link on issue
* change issue state on sidebar
* configurable issue rules

  * freeze closed issue
  * closing issue with open sub issues
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

* `bootstrap-datepicker 1.8.0 <https://github.com/uxsolutions/bootstrap-datepicker>`_
* `d3 3.5.17 <https://d3js.org/>`_
* `d3plus v2.0.0-alpha.17 <https://d3plus.org/>`_
* `FontAwesome 5.8.2 <https://fontawesome.com/>`_
* `mermaid 8.0.0 <https://github.com/knsv/mermaid/>`_
* `nvd3 1.8.6 <https://github.com/novus/nvd3>`_
* `ZeroClipboard 2.3.0 <https://github.com/zeroclipboard/zeroclipboard>`_

And a set of various Rails helper methods (see below).

It provides the following Rails helper methods :

Libraries assets loader
-----------------------

.. code-block:: ruby

  additionals_library_load(module_name)


This method loads all JS and CSS files needed by the required module.

The following modules are available :

* d3
* d3plus
* mermaid
* nvd3
* font_awesome
* notify
* zeroclipboard


Contact and Support
--------------------

I am glad about your feedback on the plugin, `pull requests <https://github.com/alphanodes/additionals/pulls>`_, `issues <https://github.com/alphanodes/additionals/issues>`_, whatever. Feel free to contact me for any questions.


.. toctree::
    :maxdepth: 2

    manual
    macros
    tasks
    new_feature
    changelog
