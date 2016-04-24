User
----

User wiki macro for Redmine.

.. function:: {{user_name [, format=FORMAT, avatar=BOOL])}}

    Display link to user profile

    :param string user_name: username (login name) or user id of the user
    :param string format: custom format of link name. If not specified system settings will be used. You can use format with the same options as for system settings.
    :param bool avatar: show avatar, if true

Examples
++++++++

Link to user profile with id 1

.. code-block:: smarty

  {{user(1)}}

Link to user profile with id 1 and show user avatar

.. code-block:: smarty

  {{user(1, avatar=true)}}

Link to user profile with login name ``admin`` and show user avatar

.. code-block:: smarty

  {{user(admin, avatar=true)}}

Link to user profile with login name ``admin`` with username as link text

.. code-block:: smarty

  {{user(admin, format=username)}}

Link to user profile with login name ``admin`` with first name as link text

.. code-block:: smarty

  {{user(admin, format=firstname)}}

Link to user profile with login name ``admin`` with last name as link text

.. code-block:: smarty

  {{user(admin, format=lastname)}}

Link to user profile with login name ``admin`` with first name and last name as link text

.. code-block:: smarty

  {{user(admin, format=firstname_lastname)}}
