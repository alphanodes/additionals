Redmine.org Issue
-----------------

Redmine.org issue wiki macro for Redmine.

.. function:: {{redmine_issue(url [, title=TITLE])}}

    Display a link to an issue on redmine.org

    :param string url: this can be an absolute path to an redmine.org issue or an issue id
    :param string title: title of link to display

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

Link to redmine.org issue with issue id

.. code-block:: smarty

  {{redmine_issue(1333)}}

Link to redmine.org issue with issue id and anchor

.. code-block:: smarty

  {{redmine_issue(1333#note-6)}}

Link to redmine.org issue with absolute url

.. code-block:: smarty

  {{redmine_issue(http://www.redmine.org/issues/12066)}}
