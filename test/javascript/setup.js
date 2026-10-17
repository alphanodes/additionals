import { vi } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Suppress jsdom/Stimulus "Node is not defined" errors during DOM cleanup.
// Stimulus's MutationObserver fires when jsdom tears down the DOM between tests,
// but the global Node constant is already gone at that point.
const originalError = console.error;
console.error = (...args) => {
  if (typeof args[0] === 'string' && args[0].includes('Node is not defined')) { return; }
  originalError.call(console, ...args);
};

if (typeof process !== 'undefined' && process.stderr) {
  const originalWrite = process.stderr.write.bind(process.stderr);
  process.stderr.write = (chunk, ...args) => {
    if (typeof chunk === 'string' && chunk.includes('Node is not defined')) { return true; }
    return originalWrite(chunk, ...args);
  };
}

// Mock AdditionalsHelpers (normally provided by additionals_stimulus.js)
globalThis.AdditionalsHelpers = {
  csrfToken: () => 'test-csrf-token',
  fetchJSON: vi.fn(),
};

// escapeHtml of additionals.js, where it is global. Only the function is taken
// from the file: running all of it would register its document listeners a
// second time in additionals.test.js, which loads it as well.
const additionalsScript = readFileSync(resolve(__dirname, '../../assets/javascripts/additionals.js'), 'utf-8');
const escapeHtmlSource = additionalsScript.match(/^function escapeHtml\(value\) \{[\s\S]*?^\}$/m)[0];
globalThis.escapeHtml = new Function(`return ${escapeHtmlSource}`)();

// Same implementation as Redmine Core's sanitizeHTML (application-legacy.js), which
// escapes &, < and > only - a stricter stand-in would hide missing quote escaping.
globalThis.sanitizeHTML = (str) => {
  const temp = document.createElement('span');
  temp.textContent = str;
  return temp.innerHTML;
};

// Polyfill Element.scrollIntoView (not implemented in jsdom)
if (typeof Element.prototype.scrollIntoView !== 'function') {
  Element.prototype.scrollIntoView = function () {};
}
