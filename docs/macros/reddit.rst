Reddit
------

Reddit wiki macro for Redmine.

.. function:: {{reddit(name)}}

    show link to Reddit

    :param string name: Reddit subject or user name

Examples
++++++++

Show link to reddit subject ``r/redmine``

.. code-block:: smarty

  {{reddit(redmine)}}

or

.. code-block:: smarty

  {{reddit(r/redmine)}}


Show link to reddit user profile ``u/redmine``

.. code-block:: smarty

  {{reddit(u/redmine)}}
