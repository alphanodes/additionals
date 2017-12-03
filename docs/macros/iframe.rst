Iframe
------

Iframe macro for Redmine.

.. function:: {{iframe(url [, width=INT, height=INT, with_link=BOOL])}}

    Include an Iframe into Redmine. If your Redmine is running with HTTPS, only iframes with
    HTTPS are accepted by this macro.

    Note: you can only include an iframe, if the website of the iframe url does allow it. If not, you
    will get a empty page with the HTTP header info:

    ``Load denied by X-Frame-Options: https://alphanodes.com/slides/redmine-cheat-sheet-macros.html#/ does not permit cross-origin framing.``

    :param string url: URL to website
    :param int width: width (default is 100%)
    :param int height: height (default is 485)
    :param bool with_link: true or false (if link to url should be displayed below iframe)

Examples
++++++++


Show iframe of URL ``https://www.google.com/``

.. code-block:: smarty

  {{iframe(https://www.google.com/)}}

Show iframe of URL https://www.google.com/ and show link to it

.. code-block:: smarty

  {{iframe(https://www.google.com/, with_link: true)}}
