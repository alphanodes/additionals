Manual
======

Content section
---------------

The content section offers several options for the user with admin rights to define texts, which will be displayed in diverse areas of Redmine.

.. note:: Use simple text, macros and wiki syntax for your content.

The following areas are available to be edited:

* Text for login page. This section is for a short information on the login page below the login mask. For example who to contact in order to get Redmine access.
* Note for new tickets. Use this section if you want to place important issue notes above every new issue. Keep it short and use a link to a common wiki page with further information.
* Overview page, right. Place information here you want to display at the right side of your overview page.
* Overview page, top. Place information here you want to display at the top of your overview page.
* Overview page, bottom. Place information here you want to display on the bottom of your overview page.
* Project guide. The project guide box will provide every user information that is necessary for your Redmine projects.
* Global sidebar. Place your global information here, if needed. Use wiki links or macros that can be seen by every one.
* Global wiki sidebar. Here you can implement useful macros like a display of your page hierarchy. But remember - only people with the correspondent rights will get a display of the content.
* Project wide wiki header
* Project wide wiki footer. For example to implement some date or author macros (e.g. last updated, updated by)
* Project wide footer. In case you want to put some information about your company or for your imprint.

Common section
--------------

The common section allows you to define some special behaviours for your Redmine installation.

The following options are available to be edited by users with admin rights:

* Change the option for ``External urls`` into default behaviour, open in new window or open with NoReferrer. Redmine must be restarted after changing ``Custom Help URL`` value before the new url is used.
* Enter a ``Custom help URL`` instead of linking to the help on Redmine.org
* Remove "Help" from top menu in order to keep the menu shorter.
* Remove "My Page" from top menu in order you don't want your users to use this page.
* Remove "Latest news" from overview page in case you do not use this function very often.
* Remove "Latest projects" from overview page because this information is often not very useful.
* Add "Go to top" link. If you have a lot of long pages, it is enabling users to easily return to the top of a page.
* ``Disable modules``, this feature will hide the selected modules in the project settings. Even if the module is enabled for use in the admin area it can not be selected by the project manager within the projects. Please note, if these modules already activated in existing projects, you will have to change and re-save the respective project settings first.


Issue rules section
-------------------

Here you can define rules, which are used in issues of all projects.

The following options are available at the moment:

* Issues with open sub-issues cannot be closed
* If "Assignee" is unchanged and the issue status changed from x to y, than the author is assigned to the issue.

.. note:: Use Case for this option: issues should be automatically assigned to autor, if the status changes to "Approval".

* Current issue status x is only allowed if "Assignee" is the current user.

.. note:: Use Case here: Users are only allowed to change the status to "In Progress" if they are the person who is actually working on the issue right now.

* If "Assigned to" is not assigned to a user and the new issue status is x then the issue is auto assigned to the first group with users of the pre-defined role.

.. note:: Use Case: The issue author does not know whom the issue should be assigned to. Or he is unsure who will be responsible for solving the task. In that case the issue for example with the status "To Do" is automatically assigned to the first group, which does contain a user of the pre-selected project manager role. Imagine you have a group called "Support", and there are users assigend to the "Manager" role, this support group will be automatically adressed to solve the issue when the issue author saves it.


Menu section
------------

Here you can define new top menu items.

.. note:: Please restart the webserver, if you remove a menu item or change permissions.

This area offers you the possibility to add up to 5 additional menu items to your Redmine main menu. The following input fields are available for each entry:

* Name. Enter the name of the menu item.
* URL. Enter an URL starting with ``http://``
* Title (optional)
* Permissions: here you select one ore more existing roles to which the menu item will be displayed.

Macro section
-------------

Because it's sometimes hard to remember what kind of macros you can use in your Redmine installation we implemented the macro section.
Here is simply displayed a list of all available Redmine macros of your installation, which are provided by Redmine in general and the installed Redmine plugins.
