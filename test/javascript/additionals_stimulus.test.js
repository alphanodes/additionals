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
  describe('loadLibrary', () => {
    const scripts = () => [...document.head.querySelectorAll('script[src^="/assets/"]')];
    // jsdom loads no scripts, the test fires their load and error events itself
    const finish = (event) => scripts().forEach((script) => script[`on${event}`]());
    // loadLibrary adds each asset after the previous one, asynchronously
    const tick = () => new Promise((done) => { setTimeout(done, 0); });

    // A page keeps loads for its lifetime, each test gets its own URLs
    let run = 0;
    const url = (file) => `/assets/${run}/${file}`;

    beforeEach(() => {
      run += 1;
      window.ADDITIONALS_LIBRARIES = {
        d3plus: [{ type: 'js', url: url('d3plus.js') }],
        chartjs_matrix: [{ type: 'js', url: url('chart.js') }, { type: 'js', url: url('matrix.js') }],
        select2: [{ type: 'css', url: url('select2.css') }],
      };
    });

    afterEach(() => {
      document.head.querySelectorAll('script[src^="/assets/"], link[href^="/assets/"]').forEach((el) => el.remove());
      delete window.ADDITIONALS_LIBRARIES;
    });

    it('rejects an unknown library', async () => {
      await expect(window.AdditionalsHelpers.loadLibrary('unknown')).rejects.toThrow('Unknown library: unknown');
    });

    it('adds the script of a library to the page', async () => {
      window.AdditionalsHelpers.loadLibrary('d3plus');
      await tick();

      expect(scripts().map((script) => script.getAttribute('src'))).toEqual([url('d3plus.js')]);
    });

    it('loads a stylesheet as link', async () => {
      window.AdditionalsHelpers.loadLibrary('select2');
      await tick();

      expect(document.head.querySelector(`link[rel="stylesheet"][href="${url('select2.css')}"]`)).not.toBeNull();
    });

    it('resolves once the library is loaded', async () => {
      const loaded = window.AdditionalsHelpers.loadLibrary('d3plus');
      await tick();
      finish('load');

      await expect(loaded).resolves.toBeUndefined();
    });

    // The assets of a library build on each other
    it('loads the next asset after the previous one', async () => {
      window.AdditionalsHelpers.loadLibrary('chartjs_matrix');
      await tick();
      const before = scripts().length;
      finish('load');
      await tick();

      expect([before, scripts().length]).toEqual([1, 2]);
    });

    it('adds a library requested twice only once', async () => {
      window.AdditionalsHelpers.loadLibrary('d3plus');
      window.AdditionalsHelpers.loadLibrary('d3plus');
      await tick();

      expect(scripts()).toHaveLength(1);
    });

    // e.g. from the libraries the server put into the head
    it('skips an asset the page has already', async () => {
      const script = document.createElement('script');
      script.setAttribute('src', url('d3plus.js'));
      document.head.appendChild(script);

      await expect(window.AdditionalsHelpers.loadLibrary('d3plus')).resolves.toBeUndefined();
    });

    it('tries a failed library again on the next request', async () => {
      const failed = window.AdditionalsHelpers.loadLibrary('d3plus');
      await tick();
      finish('error');
      await expect(failed).rejects.toThrow(`Could not load ${url('d3plus.js')}`);
      window.AdditionalsHelpers.loadLibrary('d3plus');
      await tick();

      expect(scripts()).toHaveLength(1);
    });
  });

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
