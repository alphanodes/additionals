Calendar
--------

Calendar wiki macros for Redmine.

.. function:: {{calendar([year=YEAR, month=MONTH, show_weeks=BOOL, select=DATE])}}

    Show month calendar

    :param int year: year to use, e.g. 2015
    :param int month: month to use, e.g. 4
    :param boot show_weeks: show week numbers if true

Examples
++++++++

show calendar for current date

.. code-block:: smarty

  {{calendar}}

show calendar for Juni in year ``2014``

.. code-block:: smarty

  {{calendar(year=2014,month=6)}}

show calendar with week numbers

.. code-block:: smarty

  {{calendar(show_weeks=true)}}

preselect dates and show week numbers

.. code-block:: smarty

  {{calendar(select=2015-07-12 2015-07-31, show_weeks=true)}}

preselect dates between 2016/3/13 and 2016/3/27

.. code-block:: smarty

  {{calendar(select=2016-03-13:2016-03-27)}}
