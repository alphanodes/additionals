import {
  describe, it, expect, vi,
} from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// mermaid_load.js runs after the mermaid library, so a stand-in for the
// library has to exist before the classic script is evaluated.
const libraryInitialize = vi.fn();
globalThis.mermaid = { initialize: libraryInitialize, run: vi.fn() };

const scriptPath = resolve(__dirname, '../../assets/javascripts/mermaid_load.js');
const globalEval = eval; // eslint-disable-line no-eval
globalEval(readFileSync(scriptPath, 'utf-8'));
// mocks are cleared before every test
const configOnLoad = libraryInitialize.mock.calls[0][0];

describe('mermaid_load', () => {
  it('initializes mermaid with the additionals configuration', () => {
    expect(configOnLoad.maxTextSize).toBe(500000);
  });

  // Redmine core renders fenced code blocks itself and calls initialize with
  // its own options, which would reset the additionals configuration.
  it('keeps the additionals configuration when core initializes mermaid', () => {
    globalThis.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict' });

    expect(libraryInitialize.mock.calls[0][0]).toMatchObject({ maxTextSize: 500000, startOnLoad: false, securityLevel: 'strict' });
  });
});
