/* global jsToolBar */
jsToolBar.prototype.elements.macros = {
  type: 'button',
  title: 'Macro',
  fn: {
    wiki() {
      const This = this;

      // Only what is selected goes into the macro. Enclosing the whole line
      // instead would swallow text the user did not mean to wrap, which is
      // plain to see in the visual editor.
      this.macroMenu((macro) => {
        This.encloseSelection(`{{${  macro  }(`, ')}}');
      });
    },
  },
};

/* Macro menu buttons */
jsToolBar.prototype.macroMenu = function (fn) {
  const menu = $('<ul class="additionals-macro-menu" style="position:absolute;"></ul>');
  for (let i = 0; i < this.macroList.length; i++) {
    const macroItem = $('<div></div>').text(this.macroList[i]);
    $('<li></li>').html(macroItem).appendTo(menu).on('mousedown', function () {
      fn($(this).text());
    });
  }
  $('body').append(menu);
  menu.menu().width(170).position({
    my: 'left top',
    at: 'left bottom',
    of: this.toolNodes.macros,
  });
  $(document).on('mousedown', () => {
    menu.remove();
  });
  return false;
};
