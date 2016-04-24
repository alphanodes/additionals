# Redmine tweaks plugin

[![Dependency Status](https://gemnasium.com/alexandermeindl/redmine_tweaks.svg)](https://gemnasium.com/alexandermeindl/redmine_tweaks) [![Build Status](https://drone.io/github.com/alexandermeindl/redmine_tweaks/status.png)](https://drone.io/github.com/alexandermeindl/redmine_tweaks/latest)

* use "Project guide" on project overview page
* global header for all projects
* global footer for all projects
* welcome text for login page
* global sidebar content support
* set info message above new ticket (e.g. for guidelines)
* Wiki user macros
* Wiki member macros
* Wiki project macros
* Wiki date macros
* Wiki Garfield marco
* Wiki Gist marco
* Wiki Youtube marco
* Wiki Vimeo marco
* option to remove "my page" from top menu
* customize "Help" url in top menu
* customize top menu items
* disable (hide) modules for projects
* open external urls in new window
* anonymize referrer for external urls
* Hide role in project memberbox
* Configurable issue rules
** closing issue with open sub issues
** change assigned_to_ automatically, if issue status changes
** assigned_to has changed, but status change is required, too

## Requirements

* Redmine version >= 2.6.0
* Ruby >= 2.0.0
* Gem package: see PluginGemfile

## Installation

Check the requirements!

Download the sources and put them to your vendor/plugins folder.

    $ cd {REDMINE_ROOT}
    $ git clone git://github.com/alexandermeindl/redmine_tweaks.git plugins/redmine_tweaks
    $ bundle install --without development test

Restart Redmine and have a fun!

### Custom help URL

### Description

Change help url in top menu to custom url.
Note: Redmine must be restarted after changing "Custom Help URL"</tt> value before the new url is used.


### Documentation

Documentation is available at https://redmine-tweaks.readthedocs.org.
