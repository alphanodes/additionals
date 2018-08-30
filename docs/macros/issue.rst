Issue
-----

Issue wiki macro for Redmine.

.. function:: {{issue(url [, format=FORMAT, id=ISSUE_ID, note_id=COMMENT_ID])}}

    Display a link to issue with subject (optional with an issue note)

    :param string url: URL to an issue with issue id (and note_id)
    :param string format: custom format of link name. Possible values: full, text, short or link. If not specified 'link' is used as default.
    :param int id: issue id (if this is defined, it will be always used prioritized - before the parameter for URL)
    :param int note_id: comment id (if this is defined, it will be always used prioritized - before the parameter for URL)

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

Link to issue with id and subject

.. code-block:: smarty

  {{issue(1)}}

Link to issue with id and subject by using the URL

.. code-block:: smarty

  {{issue(http://myredmine.url/issues/1)}}

Link to issue with id and subject and show comment 3

.. code-block:: smarty

  {{issue(http://myredmine.url/issues/1#note-3)}}

Link to issue with subject (without id)

.. code-block:: smarty

  {{issue(1, format=short)}}

Link to issue with tracker, subject and id

.. code-block:: smarty

  {{issue(1, format=full)}}

Display subject of issue

.. code-block:: smarty

  {{issue(1, format=text)}}
