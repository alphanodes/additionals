Redmine.org Wiki page
---------------------

Redmine.org wiki page macro for Redmine.

.. function:: {{redmine_wiki(url [, name=NAME, title=TITLE])}}

    Display a link to an issue on redmine.org

    :param string url: this can be an absolute path to an redmine.org issue or an issue id
    :param string name: name to display for link, if not specified, wiki page name is used
    :param string title: title of link to display

Scope
+++++

This macro works in all text fields with formatting support.

Examples
++++++++

Link to redmine.org wiki page with page name

.. code-block:: smarty

  {{redmine_wiki(RedmineInstall)}}

Link to redmine.org wiki page with page name and anchor

.. code-block:: smarty

  {{redmine_wiki(FAQ#How-do-I-create-sub-pages-parentchild-relationships-in-the-wiki)}}

Link to redmine.org wiki page with absolute url

.. code-block:: smarty

  {{redmine_wiki(https://www.redmine.org/projects/redmine/wiki/RedmineInstall)}}
