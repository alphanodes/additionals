Manual
======

Content section
---------------

The content section offers several options for the user with admin rights to define texts, which will be displayed in diverse areas of Redmine.

.. note:: Use simple text, macros and wiki syntax for your content.

The following areas are available to be edited:

* Text for login page
* Note for new tickets
* Overview page, right
* Overview page, top
* Overview page, bottom
* Project guide
* Global sidebar
* Global wiki sidebar
* Project wide wiki header
* Project wide wiki footer
* Project wide footer

Common section
--------------

The common section allows you to define some special behaviours for your Redmine installation.

The following options are available to be edited by users with admin rights:

* Change the option for ``External urls`` into default behaviour, open in new window or open with NoReferrer. Redmine must be restarted after changing ``Custom Help URL`` value before the new url is used.
* Enter a ``Custom help URL`` instead of linking to the help on Redmine.org
* Remove "Help" from top menu
* Remove "My Page" from top menu
* Remove "Latest projects" from overview page
* Add "Go to top" link. If you have a lot of long pages, it is helpful to add a jump to top link.
* ``Disable modules``, which should not be available for selection within the projects. If these modules already activated in existing projects, you will have to change and re-save the respective project settings first.


Issue rules section
-------------------

Here you can define rules, which are used in issues of all projects.

The following options are available at the moment:

* Issues with open sub-issues cannot be closed
* If "Assignee" is unchanged and the issue status changed from x to y, than the author is assigned to the issue.

.. note:: Use Case for this option: issues should be automatically assigned to autor, if the status changes to "Approval".

* Current issue status x is only allowed if "Assignee" is the current user.

.. note:: Use Case here: Users are only allowed to change the status to "In Progress" if they are the person who is actually working on the issue right now.

* If "Assigned to" is not assigned to someone and the new issue status is x then the issue is auto assigned to the first user with the pre-defined user role here.

.. note:: Use Case for this option: In case the issue author does not know whom to assign the issue or who will be responsible for solving the task, the issue with the example status "To Do" is automatically assigend to the first user of the pre-selected role in this section (e.g. project manager).

Menu section
------------

Here you can define new top menu items.

.. note:: Please restart the webserver, if you remove a menu item or change permissions.

This area offers you the possibility to add up to 5 additional menu items to your Redmine main menu. The following input fields are available for each entry:

* Name
* URL
* Title (optional)
* Permissions: here you select one ore more existing roles to which the menu item will be displayed.

Macro section
-------------

Because it's sometimes hard to remember what kind of macros you can use in your Redmine installation we implemented the macro section.
Here is simply displayed a list of all available Redmine macros of your installation, which are provided by Redmine in general and the installed Redmine plugins.
