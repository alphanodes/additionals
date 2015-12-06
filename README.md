# Redmine tweaks plugin

[![Dependency Status](https://gemnasium.com/alexandermeindl/redmine_tweaks.svg)](https://gemnasium.com/alexandermeindl/redmine_tweaks) [![Build Status](https://drone.io/github.com/alexandermeindl/redmine_tweaks/status.png)](https://drone.io/github.com/alexandermeindl/redmine_tweaks/latest)

* use "Project guide" on project overview page
* global header for all projects
* global footer for all projects
* welcome text for login page
* global sidebar content support
* set info message above new ticket (e.g. for guidelines)
* Wiki user macros
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


## Usage

### User macro

* user#1 links to user profile
* user:admin links to user profile

### User list macros

* users
* project members

#### Description

{{list_users}} := lists all users of the current users project

{{list_users(123)}} or {{list_users(identifier)}} or {{list_users(My project)}} := Lists all users of the project with project id 123 (or identifier or project name)

{{list_users(123, title=Manager)}} := Lists all users of the project with project id 123 and the role "Manager". If you want to use multiple roles as filters, you have to use a | as separator.

{{list_users(123, title=Manager, role=Manager only)}} := Lists all users of the project with project id 123 and the role "Manager" and adds the heading "Manager only"


### Project list macros

Lists projects of current user

#### Description

{{list_projects}} := lists all projects of current users

{{list_projects(title=My title)}} := lists all projects of current users and adds the heading "My title"


### Wiki date macros

Macro to get current date, year, month, day

#### Description

{{current_year}} := current year
{{current_month}} := current month
{{current_day}} := current day
{{current_hour}} := current hour
{{current_min}} := current minute
{{current_weekday}} := current weekday
{{current_weeknumber}} := current week number (The week starts with Monday)

### Garfield macro

{{garfield}} := show Garfield strip of the current day
{{garfield(2014,10,31)}} := show Garfield strip of 31/12/2014

### Gist macro

{{gist(6737338)}} := Show Github gist 6737338
{{gist(plentz/6737338)}} := Show Github gist 6737338

### Recently updated wiki pages

{{recently_updated}} macro displays the list of the pages that were changed within last 5 days. If you specify the argument like {{recently_updated(10)}}, it displays the pages that were changed within 10 days.

### Last updated by
{{last_updated_by}} macro displays the name of user who updated the wiki page.

### Last updated at
{{last_updated_at}} macro displays the timestamp when the wiki page was updated.

### Twitter macro

{{twitter('alphanodes')}} := links the twitter profile alphanodes

### Youtube macro

{{youtube(wvsboPUjrGc)}} := youtube video with video wvsboPUjrGc (iframe) and default size 640x360
{{youtube(wvsboPUjrGc, width=853, height=480)}} := youtube video with size 853x480
{{youtube(wvsboPUjrGc, autoplay=1)}} := youtube video and autoplay

### Vimeo macro

{{vimeo(142849533)}} := vimeo video with video 142849533 (iframe) and default size 640x360
{{vimeo(142849533, width=853, height=480)}} := vimeo video with size 853x480
{{vimeo(142849533, autoplay=1)}} := vimeo video and autoplay

### Custom help URL

### Description

Change help url in top menu to custom url.
Note: Redmine must be restarted after changing "Custom Help URL"</tt> value before the new url is used.
