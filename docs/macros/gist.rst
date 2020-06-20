Gist
----

GitHub, a service for hosting larger projects, also operates other services like Gist. Gist is for hosting code snippets. If you are using the additionals plugin for your Redmine, you can implement your Github Gist by using the following wiki macro.

.. function:: {{gist(gist)}}

    show Github gist

    :param string gist: gist to display. With or without Github username.

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

show Github gist ``6737338`` (without user name)

.. code-block:: smarty

  {{gist(6737338)}}

Show Github gist ``plentz/6737338`` (with user name)

.. code-block:: smarty

  {{gist(plentz/6737338)}}
