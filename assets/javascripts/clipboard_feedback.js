/* exported copyToClipboardWithFeedback */
/* global copyToClipboard, updateSVGIcon */

/**
 * Redmine's default tooltip options
 */
const REDMINE_TOOLTIP_OPTIONS = {
  show: {
    delay: 400
  },
  position: {
    my: 'center bottom-5',
    at: 'center top'
  }
};

/**
 * Reinitialize tooltip with Redmine's default options
 * @param {Element} target - The element to reinitialize tooltip on
 */
function reinitializeTooltip(target) {
  $(target).tooltip('destroy');
  $(target).tooltip(REDMINE_TOOLTIP_OPTIONS);
}

/**
 * Copy text to clipboard with visual feedback
 * - Elements with icon: Changes icon to checkmark
 * - Elements without icon: Changes tooltip text
 * @param {Element} target - The element that was clicked
 */
function copyToClipboardWithFeedback(target) {
  const text = target.getAttribute('data-clipboard-text');
  const iconElement = target.querySelector('svg.icon-svg');

  if (!text) return false;

  copyToClipboard(text).then(() => {
    if (iconElement) {
      // Button with icon: Change icon to checked (green checkmark)
      updateSVGIcon(target, 'checked');

      // Revert back to original icon after 2 seconds
      setTimeout(() => updateSVGIcon(target, 'copy'), 2000);
    } else {
      // Clickable text without icon: Show tooltip with "Copied!" message
      const copiedLabel = target.getAttribute('data-label-copied');

      if (copiedLabel) {
        const originalTitle = target.getAttribute('data-original-title');

        // Change title and reinitialize tooltip
        target.setAttribute('title', copiedLabel);
        reinitializeTooltip(target);

        // Trigger mouseenter to show tooltip immediately
        $(target).trigger('mouseenter');

        // Revert after 2 seconds
        setTimeout(() => {
          $(target).trigger('mouseleave');
          target.setAttribute('title', originalTitle);
          reinitializeTooltip(target);
        }, 2000);
      }
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
