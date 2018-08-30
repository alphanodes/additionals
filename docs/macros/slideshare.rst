Slideshare
----------

Slideshare wiki macro for Redmine.

.. function:: {{slideshare(key [, width=WIDTH, height=HEIGHT, slide=SLIDE])}}

    Show slideshare embedded slide

    :param string key: Slideshare embedded key code, e.g. 57941706. This is the part is the last number in url: http://de.slideshare.net/AnimeshSingh/caps-whats-best-for-deploying-and-managing-openstack-chef-vs-ansible-vs-puppet-vs-salt-57941706
    :param int width: width
    :param int height: height
    :param int slide: Slide page

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

Slideshare slide for slide ``57941706`` (iframe) and default size 595x485

.. code-block:: smarty

  {{slideshare(57941706)}}

Slideshare slide with size 514x422

.. code-block:: smarty

  {{slideshare(57941706, width=514, height=422)}}

Slideshare slide and start with page 5

.. code-block:: smarty

  {{slideshare(57941706, slide=5)}}
