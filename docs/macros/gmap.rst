Google Map
----------

Google map wiki macro for Redmine.

.. function:: {{gmap([q=QUERY, mode=MODE, width=WIDTH, height=HEIGHT])}}

    Show Google map

    :param string q: query, e.g. a city or location
    :param string mode: place, directions, search, view oder streetview (default: search)
    :param int width: widget width
    :param int height: widget height

Examples
++++++++

Show widget for Munich with ``Munich``

.. code-block:: smarty

  {{gmap(Munich)}}

Show widget for direction from Munich to Arco

.. code-block:: smarty

  {{gmap(mode=directions, origin=Munich+Aberlestr, destination=Arco)}}
