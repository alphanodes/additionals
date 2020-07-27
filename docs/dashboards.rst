Dashboards
==========

The additionals plugin version 3.0.0 comes with new dashboard support (Drag & Drop).

The dashboard configuration takes place directly in Redmine:

*  On the "Home" page
*  On the Project overview page
*  If other plugins are installed and support the dashboard functionality there might be also other areas. For example:

    * Redmine HRM Plugin: HRM overview page

Dashboard: Home
---------------

When accessing Redmine you probably get redirected to the "Home" page of the system. Users with appropriate permissions can modify the existing dashboard or add new dashboards by using the respective action links in the head section of the content area.

.. figure::  images/dashboard-home.png
   :align:   center

What you can do here is:

*  use the "Edit dashboard" link for modifications
*  add a "New dashboard"
*  Enable sidebar or Disable sidebar
*  Switch to other existing dashboards
*  Add a dashboard block
*  Move, Delete or configure added dashboard blocks


Edit Dashboard
++++++++++++++

Users with appropriate permission can edit an existing dashboard by clicking the "Edit dashboard" link to get to open the edit window.

.. figure::  images/dashboard-edit.png
   :align:   center

There you can make changes to the following fields:

Name
  The standard dashboard after the plugin installaion is called "Welcome Dashboard". Modify it according to your needs.

Description
  The dashboard description will be displayed in the sidebar next to the dashboard as soon as a dashboard has been been selected to be active.

Visible
  There are various visibility settings for a dashboard like "to me only", "to any users", "to these roles only". If you want to mak a dashboard publicly available to all other users you have to choose the option "to any users". For a specific role choose the respective role instead.

Enable sidebar
  The dashboard sidebar contains some useful information for the user. Since it is sometimes disturbing, it is hidden. To prevent this you can select this option.

Always expose
  If you want to make the dashboard name visible to the users in the head section of the dashboard page, you can activate this option.

System default
  If you want to make your dashboard system default, activate this option. So every user will have to work with it.

Author
  You can change the dashboard author in case it is necessary. This is sometimes necessary, if you create a dasboard for someone else but want this person to be able to edit it afterwards.


New Dashboard
+++++++++++++

Users with appropriate permission can add a new dashboard by clicking the "New dashboard" link in the "actions menu" to open the "New dashboard" window to fill out the following fields.

Name
  Assign a meaningful name. The dashboard name will be displayed in the sidebar for later selection. If the sidebar has been disabled, you can select the dashboard from the "Actions" menu.

Description
  The dashboard description will be displayed in the sidebar next to the dashboard as soon as a dashboard has been been selected to be active.

Visible
  There are various visibility settings for a dashboard like "to me only", "to any users", "to these roles only". If you want to mak a dashboard publicly available to all other users you have to choose the option "to any users". For a specific role choose the respective role instead.

Enable sidebar
  The dashboard sidebar contains some useful information for the user. Since it is sometimes disturbing, it is hidden. To prevent this you can choose this option.

Always expose
  If you want to make the dashboard name visible to the users in the head section of the dashboard page, you can activate this option.

System default
  If you want to make your dashboard system default, activate this option. So every user will have to work with it.


Add Dashboard blocks
++++++++++++++++++++

You can fill existing dashboards with content by using the select box "Add block".

.. figure::  images/dashboard-add-block.png
   :align:   center

The blocks that are available here depend on the functions you are using and the plugins you have on your system. They need to support the dashboard functionality of the additionals plugin. Which is not hard to do so, because it's easy to implement for plugin developers.

1. In order to add a new dashboard block, just select the respective option from the selection box. The block will be added right away.

.. note::
  The selection displays only blocks, that are allowed to be displayed on the Redmine Home page. Others are not available for selection. Currently the following plugins have additionals dashboard support implemented: DB, Passwords, Reporting, HRM, Automation, additionals


2. You probably need to position the block. In that case hover your mouse over the right block corner and grap the "Move" icon. Now position it somewhere else. If you need to remove it again use the "Delete" icon.

.. figure::  images/dashboard-actions.png
   :align:   center

.. note::
  Be careful with the deletion option. If you delete a block it will be gone right away.

3. Some blocks can be configured. In that case hover your mouse over the right block corner and click the "Options" icon. The configuration option appears and you can make your changes. Done.

.. figure::  images/dashboard-options.png
   :align:   center

.. note::
  Not every block is configurable and the block configuration may differ depending on the selection you have made. Some blocks may allow to change the column settings and other only the maximum entries, for example.


Dashboard: Project overview
---------------------------

The project overview page is also supporting the new Dashboard function. Users with appropriate permissions can modify the existing dashboard or add new dashboards by using the respective action links in the head section of the content area.

.. figure::  images/dashboard-projectoverview.png
   :align:   center

What you can do here is:

*  use the "Edit dashboard" link for modifications
*  add a "New dashboard"
*  Enable sidebar or Disable sidebar
*  Switch to other existing dashboards
*  Add a dashboard block
*  Move, Delete or configure added dashboard blocks
