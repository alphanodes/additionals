CryptoCompare
-------------

CryptoCompare is an Internet plattform where you can interactively inform yourself about the latest trends in crypto currencies and follow the development of the crypto market in real-time.

CryptoCompare wiki macro for Redmine.

See https://www.cryptocompare.com/dev/widget/wizard/ for more information.

.. function:: {{cryptocompare(options)}}

    show CryptoCompare information

    :param string fsym: default BTC
    :param string tsym: default EUR
    :param string fsyms: default BTC,ETH,LTC (if supported by widget type)
    :param string tsyms: default EUR,USD (if supported by widget type)
    :param string period: (if supported by widget type)

                          * 1D = 1 day (default)
                          * 1W = 1 week
                          * 2W = 2 weeks
                          * 1M = 1 month
                          * 3M = 3 months
                          * 6M = 6 months
                          * 1Y = 1 year

    :param string type: widget type has to be one of

                          * advanced
                          * chart (default)
                          * converter
                          * header
                          * header_v2
                          * header_v3
                          * historical
                          * list
                          * news
                          * summary
                          * tabbed
                          * titles

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

Show ``header_v3`` widget type for crypto currencies ``BTC`` and ``ETH``

.. code-block:: smarty

  {{cryptocompare(fsyms=BTC;ETH, type=header_v3)}}
