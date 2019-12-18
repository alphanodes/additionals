Slideshare
----------

Google Docs wiki macro for Redmine.

.. function:: {{google_docs(link [, width=WIDTH, height=HEIGHT, edit_link=URL])}}

    Show Google Docs embedded

    :param string link: Embedded Google docs link
    :param int width: width
    :param int height: height
    :param int edit_link: Link to edit page

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

Google docs ``https://docs.google.com/spreadsheets/d/e/2PACX-1vQL__Vgu0Y0f-P__GJ9kpUmQ0S-HG56ni_b-x4WpWxzGIGXh3X6A587SeqvJDpH42rDmWVZoUN07VGE/pubhtml`` (iframe) and default size 595x485

.. code-block:: smarty

  {{google_docs(https://docs.google.com/spreadsheets/d/e/2PACX-1vQL__Vgu0Y0f-P__GJ9kpUmQ0S-HG56ni_b-x4WpWxzGIGXh3X6A587SeqvJDpH42rDmWVZoUN07VGE/pubhtml)}}

Google docs with size 1200x1000

.. code-block:: smarty

  {{slideshare(https://docs.google.com/spreadsheets/d/e/2PACX-1vQL__Vgu0Y0f-P__GJ9kpUmQ0S-HG56ni_b-x4WpWxzGIGXh3X6A587SeqvJDpH42rDmWVZoUN07VGE/pubhtml, width=1200, height=1000)}}
