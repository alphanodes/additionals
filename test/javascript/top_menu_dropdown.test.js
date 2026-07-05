import {
  describe, it, expect, vi, beforeEach, afterEach,
} from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Load the classic script and execute it in global scope (like additionals.test.js).
// This defines the global initTopMenuDropdown function; the self-init at the bottom
// is a no-op here because the DOM has no .top-menu yet.
const scriptPath = resolve(__dirname, '../../assets/javascripts/top_menu_dropdown.js');
const scriptContent = readFileSync(scriptPath, 'utf-8');
const globalEval = eval; // eslint-disable-line no-eval
globalEval(scriptContent);

function setupDom() {
  document.body.innerHTML = `
    <nav class="top-menu">
      <ul>
        <li>
          <a class="top-submenu" href="/projects">Projects</a>
          <ul class="menu-children"><li><a href="/a">A</a></li></ul>
        </li>
        <li>
          <a class="top-submenu" href="/help">Help</a>
          <ul class="menu-children"><li><a href="/b">B</a></li></ul>
        </li>
      </ul>
    </nav>
    <div id="outside">outside</div>`;
}

function mockHover(matches) {
  window.matchMedia = vi.fn().mockReturnValue({ matches });
}

function click(el) {
  const event = new MouseEvent('click', { bubbles: true, cancelable: true });
  el.dispatchEvent(event);
  return event;
}

describe('initTopMenuDropdown', () => {
  afterEach(() => {
    document.body.innerHTML = '';
    vi.restoreAllMocks();
  });

  describe('on touch devices (hover: none)', () => {
    beforeEach(() => {
      mockHover(true);
      setupDom();
      initTopMenuDropdown();
    });

    it('opens the submenu on tap and prevents navigation', () => {
      const trigger = document.querySelectorAll('.top-submenu')[0];
      const event = click(trigger);

      expect(trigger.parentElement.querySelector('.menu-children').classList.contains('visible')).toBe(true);
      expect(event.defaultPrevented).toBe(true);
    });

    it('closes the submenu on a second tap', () => {
      const trigger = document.querySelectorAll('.top-submenu')[0];
      click(trigger);
      click(trigger);

      expect(trigger.parentElement.querySelector('.menu-children').classList.contains('visible')).toBe(false);
    });

    it('closes an open submenu when another is tapped', () => {
      const triggers = document.querySelectorAll('.top-submenu');
      click(triggers[0]);
      click(triggers[1]);

      const submenus = document.querySelectorAll('.menu-children');

      expect(submenus[0].classList.contains('visible')).toBe(false);
      expect(submenus[1].classList.contains('visible')).toBe(true);
    });

    it('closes the submenu on an outside click', () => {
      click(document.querySelectorAll('.top-submenu')[0]);
      click(document.getElementById('outside'));

      expect(document.querySelector('.menu-children').classList.contains('visible')).toBe(false);
    });

    it('closes the submenu on Escape', () => {
      click(document.querySelectorAll('.top-submenu')[0]);
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));

      expect(document.querySelector('.menu-children').classList.contains('visible')).toBe(false);
    });
  });

  describe('on pointer devices (hover: hover)', () => {
    beforeEach(() => {
      mockHover(false);
      setupDom();
      initTopMenuDropdown();
    });

    it('does not toggle on click, letting CSS hover handle it', () => {
      const trigger = document.querySelectorAll('.top-submenu')[0];
      const event = click(trigger);

      expect(trigger.parentElement.querySelector('.menu-children').classList.contains('visible')).toBe(false);
      expect(event.defaultPrevented).toBe(false);
    });
  });

  it('does nothing when there is no top-menu', () => {
    mockHover(true);
    document.body.innerHTML = '<div>no menu</div>';

    expect(() => initTopMenuDropdown()).not.toThrow();
  });
});
