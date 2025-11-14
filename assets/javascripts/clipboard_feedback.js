/* exported copyToClipboardWithFeedback */

/**
 * Copy text to clipboard with visual feedback (changes icon to checkmark)
 * @param {Element} target - The element that was clicked
 */
function copyToClipboardWithFeedback(target) {
  const text = target.getAttribute('data-clipboard-text');
  const iconElement = target.querySelector('svg.icon-svg');

  if (!text) return false;

  copyToClipboard(text).then(() => {
    // Change icon to checked (green checkmark)
    if (iconElement) {
      updateSVGIcon(target, 'checked');

      // Revert back to original icon after 2 seconds
      setTimeout(() => updateSVGIcon(target, 'copy'), 2000);
    }

    // Close dropdown menu if inside one
    if ($(target).closest('.drdn.expanded').length) {
      $(target).closest('.drdn.expanded').removeClass('expanded');
    }
  }).catch(() => {
    // Error handling - could show error icon or notification
    console.error('Failed to copy to clipboard');
  });

  return false;
}
