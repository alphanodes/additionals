New issue
---------

Create a link for "New issue" for the current user.

.. function:: {{new_issue([project_name, name=NAME])}}

    Show link to create new issue

    :param string project_name: can be project identifier, project name or project id
    :param string name: name to use for link. If not specified, "New issue" is used

    If no project_name is specified, first project is used, which the current user
    has permission to create an issue.

Scope
+++++

This macro works in all text fields with formating support.

Examples
++++++++

Link to create new issue in first available project

.. code-block:: smarty

  {{new_issue}}

Link to create new issue in project with the identifier of ``myproject``

.. code-block:: smarty

  {{new_issue(myproject)}}

Link to create new issue in project with the identifier of ``myproject`` and
with displayed link name ``New issue for broken displays``

.. code-block:: smarty

  {{new_issue(myproject, title=New issue for broken displays)}}
