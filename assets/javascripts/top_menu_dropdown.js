/* Touch support for the top-menu submenu flyouts (`.top-submenu` parents with a
 * sibling `ul.menu-children`).
 *
 * On pointer devices the flyouts open via CSS :hover (see additionals.css,
 * guarded by @media (hover: hover)). Touch devices have no hover, so a tap on
 * the parent toggles the sibling `.menu-children` `visible` class instead and
 * the first tap opens the submenu rather than following the parent link.
 * Click-outside and Escape close it again.
 *
 * Event delegation on the top-menu is used so this also covers `.menu-children`
 * that other plugins (e.g. redmine_hrm) inject into the DOM after page load.
 */

/* exported initTopMenuDropdown */
function initTopMenuDropdown() {
  const topMenu = document.querySelector('.top-menu');
  if (!topMenu || !window.matchMedia('(hover: none)').matches) {
    return;
  }

  function closeAll() {
    topMenu.querySelectorAll('.menu-children.visible').forEach((el) => {
      el.classList.remove('visible');
    });
  }

  topMenu.addEventListener('click', (event) => {
    const trigger = event.target.closest('.top-submenu');
    if (!trigger || !topMenu.contains(trigger)) {
      return;
    }

    const submenu = trigger.parentElement.querySelector('.menu-children');
    if (!submenu) {
      return;
    }

    // First tap opens the submenu instead of navigating to the parent link.
    event.preventDefault();
    const isOpen = submenu.classList.contains('visible');
    closeAll();
    if (!isOpen) {
      submenu.classList.add('visible');
    }
  });

  document.addEventListener('click', (event) => {
    if (event.target.closest('.top-menu .top-submenu') || event.target.closest('.top-menu .menu-children')) {
      return;
    }
    closeAll();
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      closeAll();
    }
  });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initTopMenuDropdown);
} else {
  initTopMenuDropdown();
}
