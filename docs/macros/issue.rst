Issue
----

Issue wiki macro for Redmine.

.. function:: {{issue(id [, format=FORMAT])}}

    Display link to issue with subject

    :param int id: issue id of the issue
    :param string format: custom format of link name. Possible values: full, text, short or link. If not specified 'link' is used as default.

Examples
++++++++

Link to issue with subject and id

.. code-block:: smarty

  {{issue(1)}}

Link to issue with subject (without id)

.. code-block:: smarty

  {{issue(1, format=short)}}

Link to issue with tracker, subject and id

.. code-block:: smarty

  {{issue(1, format=full)}}

Display subject of issue

.. code-block:: smarty

  {{issue(1, format=text)}}
