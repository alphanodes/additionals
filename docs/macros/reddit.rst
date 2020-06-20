Reddit
------

Reddit is an English-language website for social media news, web content rating and discussions. As a registered member, you can submit content, links or images and present them to other members. Link to your Reddit account or other content within Redmine by using the additionals plugin macro.

Reddit wiki macro for Redmine.

.. function:: {{reddit(name)}}

    show link to Reddit

    :param string name: Reddit subject or user name

Scope
+++++

This macro works in all text fields with formatting support.

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
