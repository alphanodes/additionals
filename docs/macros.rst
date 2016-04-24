User macro
----------

* {{user(1)}} := links to user profile
* {{user(1, avatar=true)}} := links to user profile with avatar
* {{user(admin)}} := links to user profile
* {{user(admin, format=system)}} := links to user profile with user format from system settings
* {{user(admin, format=username)}} := links to user profile with username as link text
* {{user(admin, format=firstname)}} := links to user profile with firstname as link text
* {{user(admin, format=lastname)}} := links to user profile with lastname as link text
* {{user(admin, format=lastname, avatar=true)}} := links to user profile with lastname as link text and avatar

You can use format with the same options as for system settings.

Members macros
--------------

* project members

#### Description

* {{members}} := lists all members of the current users project
* {{members(123)}} or {{members(identifier)}} or {{members(My project)}} := Lists all members of the project with project id 123 (or identifier or project name)
* {{members(123, title=Manager)}} := Lists all members of the project with project id 123 and the role "Manager". If you want to use multiple roles as filters, you have to use a | as separator.
* {{members(123, title=Manager, role=Manager only)}} := Lists all members of the project with project id 123 and the role "Manager" and adds the heading "Manager only"


Project macros
--------------

Lists projects of current user

#### Description

* {{projects}} := lists all projects of current users
* {{projects(title=My title)}} := lists all projects of current users and adds the heading "My title"


Calendar macro
--------------

* {{calendar}} := show calendar for current date
* {{calendar(year=2014,month=6)}} := show calendar for Juni in year 2014
* {{calendar(show_weeks=true)}} := show calendar with week numbers
* {{calendar(select=2015-07-12 2015-07-31, show_weeks=true)}} := preselect dates and show week numbers
* {{calendar(select=2016-03-13:2016-03-27)}} := preselect dates between 2016/3/13 and 2016/3/27


Wiki date macros
----------------

Macro to get current date, year, month, day

#### Description

* {{current_year}} := current year
* {{current_month}} := current month
* {{current_day}} := current day
* {{current_hour}} := current hour
* {{current_min}} := current minute
* {{current_weekday}} := current weekday
* {{current_weeknumber}} := current week number (The week starts with Monday)


Garfield macro
--------------

* {{garfield}} := show Garfield strip of the current day
* {{garfield(2014-10-31)}} := show Garfield strip of 31/12/2014


Gist macro
----------

* {{gist(6737338)}} := Show Github gist 6737338
* {{gist(plentz/6737338)}} := Show Github gist 6737338


Recently updated wiki pages
---------------------------

{{recently_updated}} macro displays the list of the pages that were changed within last 5 days. If you specify the argument like {{recently_updated(10)}}, it displays the pages that were changed within 10 days.


Last updated by
---------------

{{last_updated_by}} macro displays the name of user who updated the wiki page.


Last updated at
---------------

{{last_updated_at}} macro displays the timestamp when the wiki page was updated.


Twitter macro
-------------

{{twitter('alphanodes')}} := links the twitter profile alphanodes


Vimeo macro
-----------

* {{vimeo(142849533)}} := vimeo video with video 142849533 (iframe) and default size 640x360
* {{vimeo(142849533, width=853, height=480)}} := vimeo video with size 853x480
* {{vimeo(142849533, autoplay=1)}} := vimeo video and autoplay


Youtube macro
-------------

* {{youtube(wvsboPUjrGc)}} := youtube video with video wvsboPUjrGc (iframe) and default size 640x360
* {{youtube(wvsboPUjrGc, width=853, height=480)}} := youtube video with size 853x480
* {{youtube(wvsboPUjrGc, autoplay=1)}} := youtube video and autoplay
