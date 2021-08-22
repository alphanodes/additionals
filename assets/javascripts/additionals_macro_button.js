/* global jsToolBar */
jsToolBar.prototype.elements.macros = {
  type: 'button',
  title: 'Macro',
  fn: {
    wiki: function() {
      var This = this;
      this.macroMenu(function(macro){
        This.encloseLineSelection('{{' + macro + '(', ')}}');
      });
    }
  }
};

/* Macro menu buttons */
jsToolBar.prototype.macroMenu = function(fn){
  var menu = $('<ul style="position:absolute;"></ul>');
  for (var i = 0; i < this.macroList.length; i++) {
    var macroItem = $('<div></div>').text(this.macroList[i]);
    $('<li></li>').html(macroItem).appendTo(menu).mousedown(function(){
      fn($(this).text());
    });
  }
  $('body').append(menu);
  menu.menu().width(170).position({
    my: 'left top',
    at: 'left bottom',
    of: this.toolNodes['precode']
  });
  $(document).on('mousedown', function() {
    menu.remove();
  });
  return false;
};
