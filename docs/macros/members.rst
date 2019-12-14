Members, Project
----------------

Project members macro for Redmine.

.. function:: {{members([project_name, title=TITLE, role=ROLE, with_sum=BOOL])}}

    Show list of project members

    :param string project_name: can be project identifier, project name or project id
    :param string title: title to use for member list
    :param string role: only list members with this role. If you want to use multiple roles as filters, you have to use a | as separator.
    :param bool with_sum: show amount of members.

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

List all members for all projects (with the current user permission)

.. code-block:: smarty

  {{members}}

List all members for all projects and show amount of members

.. code-block:: smarty

  {{members(with_sum=true)}}

List all members for the project with the identifier of ``myproject``

.. code-block:: smarty

  {{members(myproject)}}

List all members for the project with the identifier of ``myproject``, which
have the role ``Manager``

.. code-block:: smarty

  {{members(myproject, role=Manager)}}


List all members for the project with the identifier of ``myproject``, which
have the role ``Manager`` or ``Team``

.. code-block:: smarty

  {{members(myproject, role=Manager|Team)}}

List all members for the project with name ``My project title`` and with
  box title ``My member list``

.. code-block:: smarty

  {{members(My project title, title=My member list)}}
