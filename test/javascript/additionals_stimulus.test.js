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
    let removeData;

    beforeEach(() => {
      // jQuery is not available in jsdom; core's warnLeavingUnsaved keeps its flag in jQuery data
      removeData = vi.fn();
      vi.stubGlobal('$', vi.fn(() => ({ removeData })));
    });

    afterEach(() => {
      vi.unstubAllGlobals();
    });

    it('drops the unsaved flag of all textareas by default', () => {
      window.AdditionalsHelpers.clearWarnLeavingUnsaved();

      expect($).toHaveBeenCalledWith('textarea');
    });

    it('drops the unsaved flag of the given textarea only', () => {
      const textarea = document.createElement('textarea');

      window.AdditionalsHelpers.clearWarnLeavingUnsaved(textarea);

      expect($).toHaveBeenCalledWith(textarea);
    });

    it('removes the changed key from the jQuery data store', () => {
      window.AdditionalsHelpers.clearWarnLeavingUnsaved();

      expect(removeData).toHaveBeenCalledWith('changed');
    });
  });
});
