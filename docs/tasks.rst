Tasks
=====

Additionals comes with some rake tasks, which can be used for administration.

drop_settings
-------------

.. function:: rake redmine:additionals:drop_settings plugin=PLUGIN

    Drop settings for a plugin

    :param string plugin: name of the plugin

Examples
++++++++

Remove plugin settings for redmine plugin named ``redmine_plugin_example``

.. code-block:: smarty

  bundle exec rake redmine:additionals:drop_settings RAILS_ENV=production plugin="redmine_plugin_example"



setting_set
-----------

.. function:: rake redmine:additionals:setting_set name=NAME setting=SETTING value=VALUE

    Set settings for redmine or plugin

    :param string name: name of the plugin or redmine (this is optional, if not defined redmine is used)
    :param string setting: name of setting
    :param string value: value for setting
    :param string values: list of values (seperator is ,) to generate value array automaticaly

Examples
++++++++

Set application title for Redmine

.. code-block:: smarty

  bundle exec rake redmine:additionals:setting_set RAILS_ENV=production setting="app_title" value="Redmine test instance"

Set default modules for new projects

.. code-block:: smarty

  bundle exec rake redmine:additionals:setting_set RAILS_ENV=production setting="default_projects_modules" values="issue_tracking,time_tracking,wiki"


Set plugin setting ``open_external_urls`` for plugin additionals to value 2

.. code-block:: smarty

  bundle exec rake redmine:additionals:setting_set RAILS_ENV=production name="additionals" setting="open_external_urls" value="1"


setting_get
-----------

.. function:: rake redmine:additionals:setting_get name=NAME setting=SETTING

    Get a setting of redmine or a plugin

    :param string name: name of the plugin or redmine (this is optional, if not defined redmine is used)
    :param string setting: name of setting

Examples
++++++++

Get setting for ``open_external_urls`` of the plugin additionals

.. code-block:: smarty

  bundle exec rake redmine:additionals:setting_get RAILS_ENV=production name="additionals" setting="open_external_urls"

Get ``app_title`` of redmine

.. code-block:: smarty

  bundle exec rake redmine:additionals:setting_get RAILS_ENV=production name="redmine" setting="app_title"

Get ``app_title`` of redmine

.. code-block:: smarty

  bundle exec rake redmine:additionals:setting_get RAILS_ENV=production setting="app_title"
