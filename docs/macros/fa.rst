Font Awesome
------------

Font Awesome wiki macro for Redmine.

.. function:: {{fa(icon [, class=CLASS, title=TITLE, text=TEXT, link=LINK, color=COLOR])}}

    Displays a Font Awesome icon

    :param string icon: font awesome icon name, e.g. adjust or fas_adjust
    :param string class: additional css classes
    :param string title: mouseover title
    :param string text: text, which is displayed after font awesome icon
    :param string link: link to this url
    :param string color: css color code

Scope
+++++

This macro works in all text fields with formatting support.


Examples
++++++++

Show font awesome icon "fas fa-adjust"

.. code-block:: smarty

  {{fa(adjust)}}

Show font awesome icon "fas fa-stack" and inverse

.. code-block:: smarty

  {{fa(adjust, class=fa-inverse)}}

Show font awesome icon "fas fa-adjust" with size 4x

.. code-block:: smarty

  {{fa(adjust, size=4x)}}

Show font awesome icon "fas fa-adjust" with title "Show icon"

.. code-block:: smarty

  {{fa(fas_adjust, title=Show icon)}}

Show font awesome icon "fab fa-angellist"

.. code-block:: smarty

  {{fa(fab_angellist)}}

Show font awesome icon "fas fa-adjust" and link it to https://www.redmine.org


.. code-block:: smarty

  {{fa(adjust, link=https=//www.redmine.org))}}

Show font awesome icon "fas fa-adjust" with name "Go to Redmine.org" and link it to https://www.redmine.org

.. code-block:: smarty

  {{fa(adjust, link=https=//www.redmine.de, name=Go to Redmine.org))}}

Icons
+++++

There are currently more than 1300 free Font Awesome Icons available for implementation.
The full list can be found at: https://fontawesome.com/icons?d=gallery&m=free

.. note:: All you have to do is use the icon name and implement it into your macro as mentioned above.
