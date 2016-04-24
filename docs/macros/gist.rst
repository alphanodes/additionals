Gist
----

Github gist wiki macro for Redmine.

.. function:: {{gist(gist)}}

    show Github gist

    :param string gist: gist to display. With or without Github username.


Examples
++++++++

show Github gist ``6737338`` (without user name)

.. code-block:: smarty

  {{gist(6737338)}}

Show Github gist ``plentz/6737338`` (with user name)

.. code-block:: smarty

  {{gist(plentz/6737338)}}
