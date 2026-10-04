import {
  describe, it, expect, vi,
} from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Page order: additionals.js (html head), the mermaid library, mermaid_load.js
const globalEval = eval; // eslint-disable-line no-eval
const evalScript = name => globalEval(readFileSync(resolve(__dirname, `../../assets/javascripts/${name}`), 'utf-8'));

const libraryInitialize = vi.fn();

evalScript('additionals.js');
globalThis.mermaid = { initialize: libraryInitialize, run: vi.fn() };
evalScript('mermaid_load.js');
// mocks are cleared before every test
const configOnLoad = libraryInitialize.mock.calls[0][0];

describe('mermaid_load', () => {
  it('starts rendering the macros on load', () => {
    expect(configOnLoad.startOnLoad).toBe(true);
  });

  it('initializes mermaid with the additionals configuration', () => {
    expect(configOnLoad.maxTextSize).toBe(500000);
  });
});
