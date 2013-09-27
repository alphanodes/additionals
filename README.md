# Redmine tweaks plugin

* option to remove "my page" from top menu
* Customize "Help" url in top menu
* use "Project guide" on project overview page
* Set info message above new ticket (e.g. for guidelines)
* Wiki user macros
* Wiki project macros
* Wiki date macros
* Disable (hide) modules for projects
* open external urls in new window
* anonymize referrer for external urls

## Compatibility

Tested with Redmine 2.3.3

## Installation

Download the sources and put them to your vendor/plugins folder.

    $ cd {REDMINE_ROOT}
    $ git clone git://github.com/alexandermeindl/redmine_tweaks.git plugins/redmine_tweaks

Restart Redmine and have a fun!


## Optional plugins

* Wiki extensions plugin: http://www.r-labs.org/projects/r-labs/wiki/Wiki_Extensions_en
* Wiki Lists plugin: http://www.r-labs.org/projects/wiki_lists/wiki/Wiki_Lists


## Usage

### User list macros

* users
* project members

#### Description

{{list_users}} := lists all users of the current users project

{{list_users(123)}} or {{list_users(identifier)}} or {{list_users(My project)}} := Lists all users of the project with project id 123 (or identifier or project name)

{{list_users(123, Manager)}} := Lists all users of the project with project id 123 and the role "Manager". If you want to use multiple roles as filters, you have to use a | as separator.

{{list_users(123, Manager, Manager only)}} := Lists all users of the project with project id 123 and the role "Manager" and adds the heading "Manager only"


### Project list macros

Lists projects of current user

#### Description

{{list_projects}} := lists all projects of current users

{{list_projects(My title)}} := lists all projects of current users and adds the heading "My title"


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


### Custom help URL

### Description

Change help url in top menu to custom url.
Note: Redmine must be restarted after changing "Custom Help URL"</tt> value before the new url is used.


## Changelog

### 0.4.0

- First public release
