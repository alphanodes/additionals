Meteoblue
---------

Meteoblue wiki macro for Redmine.

.. function:: {{meteoblue(location [, days=DAYS, width=WIDTH, height=HEIGHT, color=BOOL, flags...])}}

    Show weather widget from Meteoblue

    :param string location: Weather location, e.g. münchen_deutschland_2867714. This is the part after https://www.meteoblue.com/en/weather/forecast/week/
    :param int width: widget width
    :param int height: widget height
    :param bool color: color or monochrome
    :param bool pictoicon: pictoicon
    :param bool maxtemperature: maxtemperature
    :param bool mintemperature: mintemperature
    :param bool windspeed: windspeed
    :param bool windgust: windgust
    :param bool winddirection: winddirection
    :param bool uv: uv
    :param bool humidity: humidity
    :param bool precipitation: precipitation
    :param bool precipitationprobability: precipitationprobability
    :param bool spot: spot

Examples
++++++++

Show widget for Munich with ``münchen_deutschland_2867714`` (iframe)

.. code-block:: smarty

  {{meteoblue(münchen_deutschland_2867714)}}

Show widget for Munich with ``münchen_deutschland_2867714`` (iframe) and uv information

.. code-block:: smarty

  {{meteoblue(münchen_deutschland_2867714, uv=true)}}
