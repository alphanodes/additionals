Asciinema
---------

Graphical application developers often use screencasts to demonstrate functions of their programs. With Asciinema you have the possibility to record such videos, but are restricted completely to the terminal. So you can record and publish actions in the shell. With the additionals plugin macro for Asciinema you can implement such videos into Redmine.

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
