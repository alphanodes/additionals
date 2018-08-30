Vimeo
-----

Vimeo wiki macro for Redmine.

.. function:: {{vimeo(video [, width=WIDTH, height=HEIGHT, autoplay=BOOL])}}

    Show Vimeo embedded video

    :param string video: Vimeo video code, e.g. 142849533. This is the part after https://vimeo.com/
    :param int width: video width
    :param int height: video height
    :param bool autoplay: auto play video, if true

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

Vimeo video with video ``142849533`` (iframe) and default size 640x360

.. code-block:: smarty

  {{vimeo(142849533)}}

Vimeo video with size 853x480

.. code-block:: smarty

  {{vimeo(142849533, width=853, height=480)}}

Vimeo video and autoplay

.. code-block:: smarty

  {{vimeo(142849533, autoplay=true)}}
