Members, Group
--------------

Group users macro for Redmine.

.. function:: {{group_users(group_name)}}

    Show list of users in a user group (according the respective permissions)

    :param string group_name: group name

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

List all users of user group ``Team A``

.. code-block:: smarty

  {{group_users(Team A)}}
