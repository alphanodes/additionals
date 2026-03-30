import { vi } from 'vitest';

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
  fetchJSON: vi.fn()
};

// Mock sanitizeHTML (normally provided by Redmine Core)
globalThis.sanitizeHTML = (str) => {
  if (str === null || str === undefined) { return ''; }
  const s = String(str);
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#039;');
};

// Polyfill Element.scrollIntoView (not implemented in jsdom)
if (typeof Element.prototype.scrollIntoView !== 'function') {
  Element.prototype.scrollIntoView = function () {};
}
