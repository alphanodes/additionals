import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Load the script as text and execute in global scope to simulate traditional script loading
const scriptPath = resolve(__dirname, '../../assets/javascripts/additionals_stimulus.js');
const scriptContent = readFileSync(scriptPath, 'utf-8');

// Use indirect eval to execute in global scope (direct eval runs in module scope)
const globalEval = eval; // eslint-disable-line no-eval
globalEval(scriptContent);

describe('additionals_stimulus.js', () => {
  describe('clearWarnLeavingUnsaved', () => {
    let calls;

    beforeEach(() => {
      document.body.innerHTML = '<textarea id="a"></textarea><textarea id="b"></textarea>';
      calls = [];
      // jQuery is not available in jsdom; core's warnLeavingUnsaved keeps its flag in jQuery data
      vi.stubGlobal('$', vi.fn((selector) => {
        const elements = typeof selector === 'string' ? [...document.querySelectorAll(selector)] : [selector];
        return {
          toArray: () => elements,
          removeData: (key) => { calls.push(`removeData:${key}`); },
        };
      }));
    });

    afterEach(() => {
      vi.unstubAllGlobals();
    });

    it('drops the unsaved flag of all textareas by default', () => {
      window.AdditionalsHelpers.clearWarnLeavingUnsaved();

      expect($).toHaveBeenCalledWith('textarea');
    });

    it('passes the given textarea to jQuery', () => {
      const textarea = document.getElementById('a');

      window.AdditionalsHelpers.clearWarnLeavingUnsaved(textarea);

      expect($).toHaveBeenCalledWith(textarea);
    });

    it('removes the changed key from the jQuery data store', () => {
      window.AdditionalsHelpers.clearWarnLeavingUnsaved();

      expect(calls).toEqual(['removeData:changed']);
    });

    it('drops the flag only after a focused textarea fired its blur', () => {
      const textarea = document.getElementById('a');
      textarea.focus();
      textarea.addEventListener('blur', () => { calls.push('blur'); });

      window.AdditionalsHelpers.clearWarnLeavingUnsaved(textarea);

      expect(calls).toEqual(['blur', 'removeData:changed']);
    });

    it('keeps the focus on a focused textarea', () => {
      const textarea = document.getElementById('a');
      textarea.focus();

      window.AdditionalsHelpers.clearWarnLeavingUnsaved();

      expect(document.activeElement).toBe(textarea);
    });

    it('leaves the focus alone when no given textarea has it', () => {
      const other = document.getElementById('b');
      other.focus();
      other.addEventListener('blur', () => { calls.push('blur'); });

      window.AdditionalsHelpers.clearWarnLeavingUnsaved(document.getElementById('a'));

      expect(calls).toEqual(['removeData:changed']);
    });
  });
});
