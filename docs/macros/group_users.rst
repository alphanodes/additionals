Members
-------

Groupo users macro for Redmine.

.. function:: {{group_users(group_name)}}

    Show list of users in a user group (an respect permissions)

    :param string group_name: group name

Examples
++++++++

List all users of user group ``Team A``

.. code-block:: smarty

  {{group_users(Team A)}}
