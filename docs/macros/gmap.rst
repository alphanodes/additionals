Google Map
----------

Google map wiki macro for Redmine to implement a street map. There are various configuration options for presenting the GMap.

.. function:: {{gmap([q=QUERY, mode=MODE, width=WIDTH, height=HEIGHT])}}

    Show Google map

    :param string q: query, e.g. a city or location
    :param string mode: place, directions, search, view oder streetview (default: search)
    :param int width: widget width
    :param int height: widget height

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

The simplest way is to show a widget for Munich with ``Munich``

.. code-block:: smarty

  {{gmap(Munich)}}

Another option is to show a widget for direction for example from Munich to Arco (Italy)

.. code-block:: smarty

  {{gmap(mode=directions, origin=Munich+Implerstr, destination=Arco)}}
