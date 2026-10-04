import {
  describe, it, expect, vi, beforeAll,
} from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Redmine core (since 7.1) loads the mermaid library for code blocks without
// mermaid_load.js. additionals.js runs on every page before any library.
const globalEval = eval; // eslint-disable-line no-eval
globalEval(readFileSync(resolve(__dirname, '../../assets/javascripts/additionals.js'), 'utf-8'));

const libraryInitialize = vi.fn();
const library = { initialize: libraryInitialize, run: vi.fn() };

describe('mermaid configuration of additionals.js', () => {
  it('leaves mermaid undefined until the library is loaded', () => {
    expect(typeof globalThis.mermaid).toBe('undefined');
  });

  describe('when the library is loaded', () => {
    // the end of the mermaid bundle
    beforeAll(() => { globalThis.mermaid = library; });

    it('keeps the library as global mermaid', () => {
      expect(globalThis.mermaid).toBe(library);
    });

    it('adds the additionals configuration to the initialize call of core', () => {
      globalThis.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict' });

      expect(libraryInitialize.mock.calls[0][0]).toMatchObject({ maxTextSize: 500000, startOnLoad: false, securityLevel: 'strict' });
    });

    it('keeps the additionals values of a section the call sets other values of', () => {
      globalThis.mermaid.initialize({ flowchart: { curve: 'linear' } });

      expect(libraryInitialize.mock.calls[0][0].flowchart).toEqual({ useMaxWidth: false, curve: 'linear' });
    });

    it('lets the call override additionals values', () => {
      globalThis.mermaid.initialize({ maxTextSize: 1000 });

      expect(libraryInitialize.mock.calls[0][0].maxTextSize).toBe(1000);
    });

    it('adds the configuration to a library loaded a second time', () => {
      const secondInitialize = vi.fn();
      globalThis.mermaid = { initialize: secondInitialize, run: vi.fn() };
      globalThis.mermaid.initialize({});
      globalThis.mermaid = library;

      expect(secondInitialize.mock.calls[0][0].maxTextSize).toBe(500000);
    });

    it('takes the theme a Redmine theme sets', () => {
      globalThis.mermaidTheme = 'dark';
      globalThis.mermaid.initialize({});
      delete globalThis.mermaidTheme;

      expect(libraryInitialize.mock.calls[0][0].theme).toBe('dark');
    });
  });
});
