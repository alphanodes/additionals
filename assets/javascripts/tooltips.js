/*
 * jQuery UI Tooltips
 */

$(function() {
  $(document).tooltip({
    position: {
      my: "center bottom-20",
      at: "center top",
      using: function(position, feedback) {
        $(this).css(position);
        $("<div>")
          .addClass("tooltip-arrow")
          .addClass(feedback.vertical)
          .addClass(feedback.horizontal)
          .appendTo(this);
      }
    }
  });
});
