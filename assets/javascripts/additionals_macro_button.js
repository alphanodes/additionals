/* global AdditionalsWikiToolbar */
/* exported additionalsMacroButton */

/* Macro button of the wiki toolbar: a menu of the macros the page offers, the
   chosen one goes around the selection. Only what is selected goes into the
   macro. Enclosing the whole line instead would swallow text the user did not
   mean to wrap, which is plain to see in the visual editor. */
function additionalsMacroButton(macroList) {
  function openMenu(context) {
    const menu = $('<ul class="additionals-macro-menu" style="position:absolute;"></ul>');
    macroList.forEach((macro) => {
      const macroItem = $('<div></div>').text(macro);
      $('<li></li>').html(macroItem).appendTo(menu).on('mousedown', () => {
        context.wrapSelection(`{{${macro}(`, ')}}');
      });
    });
    $('body').append(menu);
    menu.menu().width(170).position({
      my: 'left top',
      at: 'left bottom',
      of: context.button,
    });
    $(document).one('mousedown', () => {
      menu.remove();
    });
  }

  AdditionalsWikiToolbar.register('macros', { title: 'Macro', onClick: openMenu });
}
