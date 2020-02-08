Google Docs
-----------

Google Docs wiki macro for Redmine. Google Docs is an online word processor that you can use to create, format, and collaborate on documents. The macro helps you to integrat a Google Docs document as iframe into a Redmine text field.

.. function:: {{google_docs(link[, width=WIDTH, height=HEIGHT, edit_link=URL])}}

    Show Google Docs embedded

    :param string link: Embedded Google docs link
    :param int width: width (if not specified, 100% is used)
    :param int height: height (if not specified, 485 is used)
    :param int edit_link: Link to edit page

Scope
+++++

This macro works in all text fields with formatting support (e.g. Redmine Wiki).

Examples
++++++++

Google docs ``https://docs.google.com/spreadsheets/d/e/2PACX-1vQL__Vgu0Y0f-P__GJ9kpUmQ0S-HG56ni_b-x4WpWxzGIGXh3X6A587SeqvJDpH42rDmWVZoUN07VGE/pubhtml`` (iframe) and default size 100% x 485

.. code-block:: smarty

  {{google_docs(https://docs.google.com/spreadsheets/d/e/2PACX-1vQL__Vgu0Y0f-P__GJ9kpUmQ0S-HG56ni_b-x4WpWxzGIGXh3X6A587SeqvJDpH42rDmWVZoUN07VGE/pubhtml)}}

Google docs with size 1200 x 1000

.. code-block:: smarty

  {{slideshare(https://docs.google.com/spreadsheets/d/e/2PACX-1vQL__Vgu0Y0f-P__GJ9kpUmQ0S-HG56ni_b-x4WpWxzGIGXh3X6A587SeqvJDpH42rDmWVZoUN07VGE/pubhtml, width=1200, height=1000)}}
