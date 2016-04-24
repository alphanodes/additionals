Garfield
--------

Garfield wiki macro for Redmine.

.. function:: {{garfield([date])}}

    show Garfield strip of the day

    :param string date: date to use with format YEAR-MONTH-DAY. If not specified current date is used.


Examples
++++++++

show Garfield strip of the current day

.. code-block:: smarty

  {{garfield}}

show Garfield strip of ``31/12/2014``

.. code-block:: smarty

  {{garfield(2014-10-31)}}
