import {
  describe, it, expect, vi, beforeEach,
} from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Page order: additionals.js (html head), the mermaid library, mermaid_load.js
const globalEval = eval; // eslint-disable-line no-eval
const evalScript = name => globalEval(readFileSync(resolve(__dirname, `../../assets/javascripts/${name}`), 'utf-8'));

// jsdom has no layout: whether a diagram is displayed is set per element, and
// the ResizeObserver reports when it is shown.
const observers = [];
globalThis.ResizeObserver = class {
  constructor(callback) {
    this.callback = callback;
    this.disconnect = vi.fn();
    observers.push(this);
  }

  observe(element) {
    this.element = element;
  }
};

// A diagram is displayed where its parent is: plugins hide the diagram itself until it is rendered
const setShown = (element, shown) => {
  element.parentElement.getClientRects = () => (shown ? [{ width: 10, height: 10 }] : []);
};

const libraryInitialize = vi.fn();
const libraryRun = vi.fn(() => Promise.resolve());

evalScript('additionals.js');
globalThis.mermaid = { initialize: libraryInitialize, run: libraryRun };
evalScript('mermaid_load.js');
// additionals.js initializes the library first, mermaid_load.js last.
// Mocks are cleared before every test.
const configOnLoad = libraryInitialize.mock.calls.at(-1)[0];

describe('mermaid_load', () => {
  beforeEach(() => {
    observers.length = 0;
    document.body.innerHTML = '';
  });

  // Rendering on load is left to mermaid_load.js, which skips diagrams that
  // are not displayed yet
  it('does not let mermaid render on load by itself', () => {
    expect(configOnLoad.startOnLoad).toBe(false);
  });

  it('initializes mermaid with the additionals configuration', () => {
    expect(configOnLoad.maxTextSize).toBe(500000);
  });

  it('renders the diagrams on load that are not rendered yet', () => {
    document.body.innerHTML = '<div><div class="mermaid" id="new">graph LR</div><div class="mermaid" data-processed="true">done</div></div>';
    setShown(document.getElementById('new'), true);

    window.dispatchEvent(new Event('load'));

    expect(libraryRun).toHaveBeenCalledWith({ nodes: [document.getElementById('new')], suppressErrors: true });
  });

  // A diagram in a collapsed block has no size, mermaid would lay it out as an empty 16x16 picture
  it('renders a diagram that is not displayed once it is shown', async () => {
    document.body.innerHTML = '<div class="collapsed-text"><div class="mermaid" id="hidden">graph LR</div></div>';
    const diagram = document.getElementById('hidden');
    setShown(diagram, false);

    await globalThis.renderMermaidMacro('.mermaid');
    await globalThis.renderMermaidMacro('.mermaid');

    expect(libraryRun).not.toHaveBeenCalled();
    expect(observers).toHaveLength(1);
    expect(observers[0].element).toBe(diagram.parentElement);

    observers[0].callback();

    expect(libraryRun).not.toHaveBeenCalled();

    setShown(diagram, true);
    observers[0].callback();

    expect(observers[0].disconnect).toHaveBeenCalled();
    expect(libraryRun).toHaveBeenCalledWith({ nodes: [diagram], suppressErrors: true });
  });
});
