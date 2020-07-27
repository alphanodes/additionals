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

*  Edit dashboard
*  New dashboard
*  Enable sidebar or Disable sidebar
*  Switch to other existing dashboards
*  Add a dashboard block
*  Move, Delete or configure added dashboard blocks


Edit Dashboard
--------------

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
-------------

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
