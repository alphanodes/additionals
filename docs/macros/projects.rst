Projects
--------

Projects wiki macro for Redmine.

.. function:: {{projects([title=TITLE, with_create_issue=BOOL])}}

    Lists projects of the current user

    :param string title: title to use for project list
    :param bool with_create_issue: show link to create new issue, if true

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

List all projects of the current users

.. code-block:: smarty

  {{projects}}

List all projects of the current users and adds the heading ``My project list``

.. code-block:: smarty

  {{projects(title=My project list)}}

List all project with link to create new issue, which I am member of

.. code-block:: smarty

  {{projects(with_create_issue=true)}}
