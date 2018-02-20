Recently updated
----------------

Recently updated wiki macro for Redmine.

.. function:: {{recently_updated([days])}}

    show the list of the pages that were changed recently.

    :param int days: number of days, which should be used. Default is 5.

Scope
+++++

This macro only works in wiki page contexts.

Examples
++++++++

List last updated pages (of the last 5 days)

.. code-block:: smarty

  {{recently_updated}}

List last updated pages of the last 15 days

.. code-block:: smarty

  {{recently_updated(15)}}
