User
----

User wiki macro for Redmine.

.. function:: {{user(user [, format=FORMAT, text=BOOL, avatar=BOOL])}}

    Display link to user profile

    :param string user: user name (login name) or user id of the user. If current user is used as login name the currently logged in user will be used.
    :param string format: custom format of link name. If not specified system settings will be used. You can use format with the same options as for system settings.
    :param bool text: show text only (without link), if true (default: false)
    :param bool avatar: show avatar, if true (default: false)

Scope
+++++

This macro works in all text fields with formatting support.

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

Display name of currently logged in user with username as text

.. code-block:: smarty

  {{user(current_user, text=true)}}

Display name of currently logged in user with username

.. code-block:: smarty

  {{user(current_user)}}
