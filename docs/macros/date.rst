Date
----

.. function:: {{date([TYPE])}}

    Display current date

    :param string TYPE: current_date (default) current date
                        current_date_with_time current date with time
                        current_year           current year
                        current_month          current month
                        current_day            current day
                        current_hour           current hour
                        current_minute         current minute
                        current_weekday        current weekday
                        current_weeknumber     current week number (1 - 52) The week starts with Monday

Scope
+++++

This macro works in all text fields with formatting support.


Examples
++++++++

Show current date.

.. code-block:: smarty

  {{date}}

Show current date with time

.. code-block:: smarty

   {{date(current_date_with_time)}}


Show current year

.. code-block:: smarty

   {{date(current_year)}}


Show current week number

.. code-block:: smarty

   {{date(current_weeknumber)}}
