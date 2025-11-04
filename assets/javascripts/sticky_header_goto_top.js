/* Adds click-to-scroll functionality to sticky headers
 * When clicking on the sticky header, smoothly scrolls back to the original element
 */

(function() {
  'use strict';

  function initStickyHeaderGotoTop() {
    const stickyHeader = document.querySelector('#sticky-issue-header');
    if (!stickyHeader) return;

    // Add visual styling - just cursor to indicate clickability
    stickyHeader.style.cursor = 'pointer';

    // Add tooltip with translated text
    const tooltipText = window.ADDITIONALS_I18N && window.ADDITIONALS_I18N.goToTop
      ? window.ADDITIONALS_I18N.goToTop
      : 'Go to top';
    stickyHeader.setAttribute('title', tooltipText);

    // Add click handler - scroll to top of page
    stickyHeader.addEventListener('click', function(event) {
      event.preventDefault();
      window.scrollTo({
        top: 0,
        behavior: 'smooth'
      });
    });
  }

  // Initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initStickyHeaderGotoTop);
  } else {
    initStickyHeaderGotoTop();
  }

  // Re-initialize on Turbo page loads (if Turbo is used)
  if (typeof Turbo !== 'undefined') {
    document.addEventListener('turbo:load', initStickyHeaderGotoTop);
  }
})();
