# Redmine tweaks plugin

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
* Wiki Youtube marco
* option to remove "my page" from top menu
* customize "Help" url in top menu
* customize top menu items
* disable (hide) modules for projects
* open external urls in new window
* anonymize referrer for external urls


## Requirements

* Redmine version >= 2.4.6


## Installation

Check the requirements!

Download the sources and put them to your vendor/plugins folder.

    $ cd {REDMINE_ROOT}
    $ git clone git://github.com/alexandermeindl/redmine_tweaks.git plugins/redmine_tweaks

Restart Redmine and have a fun!


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

### Garfield macro

{{garfield}} := show Garfield strip of the current day
{{garfield(2014,10,31)}} := show Garfield strip of 31/12/2014


### Youtube macro

{youtube(wvsboPUjrGc)}} := youtube video with video wvsboPUjrGc (iframe) and default size 640x360
{{youtube(wvsboPUjrGc,853,480)}} := youtube video with size 853x480
{{youtube(wvsboPUjrGc,853,480,1)}} := youtube video with size 853x480 and autoplay
{{youtube(wvsboPUjrGc,,,1)}} := youtube video with size 853x480 and autoplay


### Custom help URL

### Description

Change help url in top menu to custom url.
Note: Redmine must be restarted after changing "Custom Help URL"</tt> value before the new url is used.


## Changelog

### 0.5.0

- Redmine 2.6.x compatiblity
- URL fixes
- Garfield macro has been added 

### 0.4.9

- added overview text field
- fix style for "goto top"
- added macro overview help page
- fix compatiblity problems with sidebar and other plugins

### 0.4.8

- added youtube macro
- project guide subject can be defined for project overview page

### 0.4.7

- added jump to top link
- top menu item configuration has been added
- footer configuration (e.g. for imprint url) has been added

### 0.4.6

- initialize plugins settings now works with other plugins

### 0.4.5

- option to remove help menu item
- Redmine 2.4.1 required

### 0.4.4

- installation error fixed
- description update for link handling
- help url now opens in new windows
- sidebar error has been fixed, if no wiki page already exist

### 0.4.3

- global gantt and calendar bugfix

### 0.4.2

- no requirements of Wiki extensions plugin anymore

### 0.4.1

- Fix problem with my page permission

### 0.4.0

- First public release
