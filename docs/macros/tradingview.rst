TradingView
-----------

TradingView wiki macro for Redmine.

See https://www.tradingview.com/widget/ for more information.

.. function:: {{tradingview(options)}}

    show TradingView chart

    :param int width: default 640
    :param int height: default 480
    :param string symbol: default NASDAQ:AAPL
    :param string interval: default W
    :param string timezone: default Europe/Berlin
    :param string theme: default White
    :param int style: default 2
    :param string locale: default de
    :param string toolbar_bg: default #f1f3f6
    :param bool enable_publishing: default false
    :param bool allow_symbol_change: default true
    :param bool hideideasbutton: default true

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

Show chart with symbol ``NASDAQ:AMZN`` and use English locale

.. code-block:: smarty

  {{tradingview(symbol=NASDAQ:AMZN, locale=en)}}
