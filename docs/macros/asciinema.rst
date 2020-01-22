Asciinema
----

asciinema.org wiki macro for Redmine.

.. function:: {{asciinema(cast_id)}}

    show asciinema.org cast

    :param string cast_id: asciinema.org asciicast id

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

show asciinema.org cast_id ``113463``

.. code-block:: smarty

  {{asciinema(113463)}}
