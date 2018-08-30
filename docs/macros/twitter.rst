Twitter
-------

Twitter wiki macro for Redmine.

.. function:: {{twitter(profile)}}

    show link to Twitter profile

    :param string profile: Twitter profile name with @. E.g. alphanodes

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

Show link to twitter profile ``@alphanodes``

.. code-block:: smarty

  {{twitter(alphanodes)}}

or

.. code-block:: smarty

  {{twitter(@alphanodes)}}


Show link to hashtag ``#redmine``

.. code-block:: smarty

  {{twitter(#redmine)}}
