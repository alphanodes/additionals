import { describe, it, expect, beforeEach, vi } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Load the script as text and execute in global scope to simulate traditional script loading
const scriptPath = resolve(__dirname, '../../assets/javascripts/additionals.js');
const scriptContent = readFileSync(scriptPath, 'utf-8');

// Mock Redmine Core globals
globalThis.replaceInHistory = vi.fn();

// Use indirect eval to execute in global scope (direct eval runs in module scope)
const globalEval = eval; // eslint-disable-line no-eval
globalEval(scriptContent);

describe('additionals.js', () => {
  describe('openExternalUrlsInTab', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <a href="https://example.com" class="external">External</a>
        <a href="/internal" class="internal">Internal</a>
        <a href="https://other.com" class="external">Other</a>
      `;
    });

    it('sets target and rel on external links', () => {
      openExternalUrlsInTab();

      const externals = document.querySelectorAll('a.external');

      expect(externals[0].getAttribute('target')).toBe('_blank');
      expect(externals[0].getAttribute('rel')).toBe('noopener noreferrer');
      expect(externals[1].getAttribute('target')).toBe('_blank');
    });

    it('does not modify non-external links', () => {
      openExternalUrlsInTab();

      const internal = document.querySelector('a.internal');

      expect(internal.getAttribute('target')).toBeNull();
    });
  });

  describe('formatNameWithIcon', () => {
    it('returns name when loading', () => {
      const result = formatNameWithIcon({ loading: true, name: 'Loading...' });

      expect(result).toBe('Loading...');
    });

    it('returns span with name_with_icon when present', () => {
      const result = formatNameWithIcon({ name_with_icon: '<b>Icon</b> Name' });

      expect(result.tagName).toBe('SPAN');
      expect(result.innerHTML).toBe('<b>Icon</b> Name');
    });

    it('returns span with text as fallback', () => {
      const result = formatNameWithIcon({ text: 'Plain text' });

      expect(result.tagName).toBe('SPAN');
      expect(result.innerHTML).toBe('Plain text');
    });
  });

  describe('formatIconOption', () => {
    it('returns span with an svg icon when id and data-href are present', () => {
      const element = document.createElement('option');
      element.dataset.href = '/assets/additionals/icons.svg#icon--home';
      const result = formatIconOption({ id: 'home', text: 'Home', element });

      expect(result.tagName).toBe('SPAN');
      expect(result.innerHTML).toContain('icon--home');
      expect(result.innerHTML).toContain('Home');
    });

    it('returns span with only text when data-href is missing', () => {
      const element = document.createElement('option');
      const result = formatIconOption({ id: 'home', text: 'Home', element });

      expect(result.tagName).toBe('SPAN');
      expect(result.innerHTML).toBe('Home');
    });

    it('returns text when id is undefined', () => {
      const result = formatIconOption({ text: 'No icon' });

      expect(result).toBe('No icon');
    });
  });

  describe('showPluginSettingsTab', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <form action="/settings/plugin/test">
          <div class="tabs">
            <a id="tab-general" class="selected" href="#">General</a>
            <a id="tab-advanced" href="#">Advanced</a>
          </div>
          <div id="tab-content-general" class="tab-content">General content</div>
          <div id="tab-content-advanced" class="tab-content" style="display:none">Advanced content</div>
        </form>
      `;
      globalThis.replaceInHistory.mockClear();
    });

    it('shows the selected tab content', () => {
      showPluginSettingsTab('advanced', '/settings/plugin/test?tab=advanced');

      expect(document.getElementById('tab-content-advanced').style.display).toBe('');
      expect(document.getElementById('tab-content-general').style.display).toBe('none');
    });

    it('updates the selected tab link', () => {
      showPluginSettingsTab('advanced', '/settings/plugin/test?tab=advanced');

      expect(document.getElementById('tab-advanced').classList.contains('selected')).toBe(true);
      expect(document.getElementById('tab-general').classList.contains('selected')).toBe(false);
    });

    it('calls replaceInHistory with url', () => {
      showPluginSettingsTab('advanced', '/settings/plugin/test?tab=advanced');

      expect(globalThis.replaceInHistory).toHaveBeenCalledWith('/settings/plugin/test?tab=advanced');
    });

    it('updates form action with tab parameter', () => {
      showPluginSettingsTab('advanced', '/settings/plugin/test?tab=advanced');

      expect(document.querySelector('form').getAttribute('action')).toContain('tab=advanced');
    });

    it('appends tab to URL without existing query params', () => {
      showPluginSettingsTab('general', '/url');

      expect(document.querySelector('form').getAttribute('action')).toBe('/settings/plugin/test?tab=general');
    });

    it('returns false', () => {
      const result = showPluginSettingsTab('advanced', '/url');

      expect(result).toBe(false);
    });
  });

  describe('variable cheat-sheets', () => {
    // markup as link_to_show_variables and the variable list render it
    function setupDom({ target = null, focusField = false } = {}) {
      const insertTarget = target ? ` data-insert-target="${target}"` : '';
      document.body.innerHTML = `
        <p>
          <input id="my_field" value="">
          <textarea id="other_field" class="variable-value"></textarea>
          <em class="info"><a href="#" class="show-variables">Show variables</a></em>
          <em class="info available-variables toggle-variables"${insertTarget}>
            <a href="#" class="var">{%name%}</a>
          </em>
        </p>
      `;

      if (focusField) {
        document.getElementById('other_field').dispatchEvent(new FocusEvent('focus'));
      }
    }

    function click(selector) {
      document.querySelector(selector)
        .dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
    }

    it('reveals the list and hides the link', () => {
      setupDom();

      click('a.show-variables');

      expect(document.querySelector('em.available-variables').classList.contains('toggle-variables')).toBe(false);
      expect(document.querySelector('a.show-variables').style.display).toBe('none');
    });

    it('reveals the list named by data-show-target', () => {
      document.body.innerHTML = `
        <p>
          <em class="info"><a href="#" class="show-variables" data-show-target="second_list">Show</a></em>
          <em class="info available-variables toggle-variables" id="first_list"></em>
          <em class="info available-variables toggle-variables" id="second_list"></em>
        </p>
      `;

      click('a.show-variables');

      expect(document.getElementById('second_list').classList.contains('toggle-variables')).toBe(false);
      expect(document.getElementById('first_list').classList.contains('toggle-variables')).toBe(true);
    });

    it('inserts a variable into the field named by data-insert-target', () => {
      setupDom({ target: 'my_field' });

      click('a.var');

      expect(document.getElementById('my_field').value).toBe('{%name%}');
    });

    it('inserts a variable at the cursor position', () => {
      setupDom({ target: 'my_field' });
      const field = document.getElementById('my_field');
      field.value = 'ab';
      field.selectionStart = 1;
      field.selectionEnd = 1;

      click('a.var');

      expect(field.value).toBe('a{%name%}b');
    });

    it('inserts into the last focused field when no target is named', () => {
      setupDom({ focusField: true });

      click('a.var');

      expect(document.getElementById('other_field').value).toBe('{%name%}');
    });

    it('leaves the fields alone when nothing was focused', () => {
      setupDom();

      click('a.var');

      expect(document.getElementById('my_field').value).toBe('');
      expect(document.getElementById('other_field').value).toBe('');
    });
  });
});
