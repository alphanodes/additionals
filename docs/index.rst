.. Additionals documentation master file, created by
   sphinx-quickstart on Sat Apr 23 16:31:21 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

.. _Redmine: https://www.redmine.org
.. _Ruby: https://www.ruby-lang.org
.. _PluginGemfile: https://github.com/alphanodes/additionals/blob/master/PluginGemfile

Welcome to Additionals Plugin for Redmine
=========================================

Additionals is a `Redmine`_ plugin for customizing Redmine, providing wiki macros and act as a library/function provider for other Redmine plugins.

This plugin is the successor of `Redmine Tweaks <https://github.com/alphanodes/redmine_tweaks>`_


* Documentation: https://additionals.readthedocs.io
* Redmine.org plugin page: https://www.redmine.org/plugins/additionals
* Github: https://github.com/alphanodes/additionals

.. image:: https://gemnasium.com/badges/github.com/AlphaNodes/additionals.svg
   :target: https://gemnasium.com/github.com/AlphaNodes/additionals

.. image:: https://pm.alphanodes.com/jenkins/buildStatus/icon?job=Devel-build-additionals
   :target: https://pm.alphanodes.com/jenkins/buildStatus/icon?job=Devel-build-additionals
   :alt: Jenkins Build Status

.. image:: https://readthedocs.org/projects/additionals/badge/?version=latest
   :target: http://additionals.readthedocs.io/en/latest/?badge=latest
   :alt: Documentation Status

.. image:: https://img.shields.io/codeclimate/github/AlphaNodes/additionals.svg?style=flat
   :target: https://codeclimate.com/github/AlphaNodes/additionals
   :alt: Code Climate

.. image:: https://img.shields.io/badge/rate%20at-redmine.org-blue.svg?style=flat
   :target: https://www.redmine.org/plugins/additionals
   :alt: Rate at redmine.org

Requirements
------------

+--------------------+----------------------+
| `Redmine`_ version | >= 3.0.0             |
+--------------------+----------------------+
| `Ruby`_ version    | >= 2.1.5             |
+--------------------+----------------------+
| Gem packages       | see `PluginGemfile`_ |
+--------------------+----------------------+


Installation
------------

Install ``additionals`` plugin for `Redmine`_.

.. code-block:: bash

  $ cd $REDMINE_ROOT
  $ git clone git://github.com/alphanodes/additionals.git plugins/additionals
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


Uninstall
---------

Uninstall ``additionals`` plugin for `Redmine`_.

.. code-block:: bash

  $ cd $REDMINE_ROOT
  $ bundle exec rake redmine:plugins:migrate NAME=additionals VERSION=0 RAILS_ENV=production
  $ rm -rf plugins/additionals


Features
--------

* use "Project guide" on project overview page
* global header for all projects
* global footer for all projects
* welcome text for login page
* global sidebar content support
* set info message above new ticket (e.g. for guidelines)
* Wiki macros for: date, Gihub gist, issues, members, projects slideshare, twitter, reddit, tradingview, cryptocompare, user, youtube and vimeo
* option to remove "my page" from top menu
* customize "Help" url in top menu
* customize top menu items
* disable (hide) modules for projects
* open external urls in new window
* smiley/emoji legacy support
* anonymize referrer for external urls
* Hide role in project memberbox
* Change issue author
* Add involved issue users as watcher automatically
* Configurable issue rules

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

* `angular-gantt 1.2.13 <https://github.com/angular-gantt/angular-gantt>`_
* `bootstrap 3.3.7 <https://getbootstrap.com>`_
* `d3 3.5.16 <https://d3js.org/>`_
* `d3plus 1.9.8 <http://d3plus.org/>`_
* `jQuery TagIt 2.0 <http://aehlke.github.io/tag-it/>`_
* `FontAwesome 4.7.0 <http://fontawesome.io/>`_
* `nvd3 1.8.5 <https://github.com/novus/nvd3>`_
* `ZeroClipboard 2.2.0 <https://github.com/zeroclipboard/zeroclipboard>`_

And a set of various Rails helper methods (see below).

It provides the following Rails helper methods :

Libraries assets loader
-----------------------

.. code-block:: ruby

  additionals_library_load(module_name)


This method loads all JS and CSS files needed by the required module.

The following modules are available :

* angular_gantt
* bootstrap
* bootstrap_theme (bootstrap with theme)
* d3
* d3plus
* nvd3
* font_awesome
* glyphicons
* notify
* tag_it
* tooltips
* zeroclipboard


Contact and Support
--------------------

I am glad about your feedback on the plugin, `pull requests <https://github.com/alphanodes/additionals/pulls>`_, `issues <https://github.com/alphanodes/additionals/issues>`_, whatever. Feel free to contact me for any questions.


.. toctree::
    :maxdepth: 2

    manual
    macros
    new_feature
    changelog
