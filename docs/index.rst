.. redmine_tweaks documentation master file, created by
   sphinx-quickstart on Sat Apr 23 16:31:21 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to Redmine Tweaks Plugin
================================

.. image:: https://gemnasium.com/alexandermeindl/redmine_tweaks.svg
    :target: https://gemnasium.com/alexandermeindl/redmine_tweaks

.. image:: https://drone.io/github.com/alexandermeindl/redmine_tweaks/status.png
    :target: https://drone.io/github.com/alexandermeindl/redmine_tweaks/latest

.. toctree::
   :maxdepth: 2


Requirements
============

* Redmine version >= 2.6.0
* Ruby >= 2.0.0
* Gem package: see PluginGemfile


Installation
============

Install redmine_tweaks

Check the requirements!

Download the sources and put them to your plugins folder.

.. code-block:: bash

  $ cd $REDMINE_ROOT
  $ git clone git://github.com/alexandermeindl/redmine_tweaks.git plugins/redmine_tweaks
  $ bundle install --without development test


Table of contents
-----------------

.. toctree::
    :maxdepth: 2

    features
    macros
    changelog
