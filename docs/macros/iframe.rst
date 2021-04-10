Iframe
------

Iframe macro for Redmine. The iframe is a square HTML element. It can be embedded e.g. within a Wiki page of Redmine. Via an iframe, content from other Internet pages can be integrated just like via a small integrated browser window.

For example you can integrate a HedgeDoc Pad page into your Wiki pages.

.. function:: {{iframe(url [, width=INT, height=INT, with_link=BOOL])}}

    Include an Iframe into Redmine. If your Redmine is running with HTTPS, only iframes with
    HTTPS are accepted by this macro.

    :param string url: URL to website
    :param int width: width (default is 100%)
    :param int height: height (default is 485)
    :param bool with_link: true or false (if link to url should be displayed below iframe)

    Note 1: you can only include an iframe, if the website of the iframe url does allow it. If not, you
    will get a empty page with the HTTP header info:

    ``Load denied by X-Frame-Options: https://your-target-url.com/ does not permit cross-origin framing.``

    Note 2: Your Redmine webserver can also block your iframe inclusion, check your `Content Security Policy (CSP) <https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP>`_

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++


Show iframe of URL ``https://www.google.com/``

.. code-block:: smarty

  {{iframe(https://www.google.com/)}}

Show iframe of URL https://www.google.com/ and show link to it

.. code-block:: smarty

  {{iframe(https://www.google.com/, with_link: true)}}
