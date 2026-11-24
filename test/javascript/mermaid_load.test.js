import {
  describe, it, expect, vi, beforeEach,
} from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import vm from 'vm';

// Page order: additionals.js (html head), the mermaid library, mermaid_load.js
const globalEval = eval; // eslint-disable-line no-eval
const scriptSource = name => readFileSync(resolve(__dirname, `../../assets/javascripts/${name}`), 'utf-8');
const evalScript = name => globalEval(scriptSource(name));

// jsdom has no layout: whether a diagram is displayed is set per element, and
// the ResizeObserver reports the elements whose size changed.
const observers = [];
globalThis.ResizeObserver = class {
  constructor(callback) {
    this.callback = callback;
    this.targets = new Set();
    observers.push(this);
  }

  observe(element) {
    this.targets.add(element);
  }

  unobserve(element) {
    this.targets.delete(element);
  }

  report(...elements) {
    this.callback(elements.map(target => ({ target })));
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

  it('skips diagrams that are already rendered', async () => {
    document.body.innerHTML = '<div><div class="mermaid" data-processed="true">done</div></div>';
    setShown(document.querySelector('.mermaid'), false);

    await globalThis.renderMermaidMacro('.mermaid');

    expect(libraryRun).not.toHaveBeenCalled();
    expect(observers.every(observer => observer.targets.size === 0)).toBe(true);
  });

  // A diagram in a collapsed block has no size, mermaid would lay it out as an
  // empty 16x16 picture. All diagrams shown at the same time are rendered by
  // one mermaid.run call, two calls could give them the same SVG id.
  it('renders the diagrams that are not displayed together once they are shown', async () => {
    document.body.innerHTML = `
      <div class="collapsed-text">
        <div class="pre-wrapper"><div class="mermaid" id="first">graph LR</div></div>
        <div class="pre-wrapper"><div class="mermaid" id="second">graph TD</div></div>
      </div>`;
    const first = document.getElementById('first');
    const second = document.getElementById('second');
    setShown(first, false);
    setShown(second, false);

    await globalThis.renderMermaidMacro('.mermaid');
    await globalThis.renderMermaidMacro('.mermaid');

    expect(libraryRun).not.toHaveBeenCalled();
    expect(observers).toHaveLength(1);
    const [observer] = observers;
    expect([...observer.targets]).toEqual([first.parentElement, second.parentElement]);

    observer.report(first.parentElement, second.parentElement);

    expect(libraryRun).not.toHaveBeenCalled();

    setShown(first, true);
    setShown(second, true);
    observer.report(first.parentElement, second.parentElement);

    expect(libraryRun).toHaveBeenCalledTimes(1);
    expect(libraryRun).toHaveBeenCalledWith({ nodes: [first, second], suppressErrors: true });
    expect(observer.targets.size).toBe(0);
  });

  it('stops waiting for a diagram whose content was replaced', async () => {
    document.body.innerHTML = '<div id="box"><div><div class="mermaid" id="gone">graph LR</div></div></div>';
    const diagram = document.getElementById('gone');
    setShown(diagram, false);

    await globalThis.renderMermaidMacro('#gone');
    const [observer] = observers.slice(-1);
    const parent = diagram.parentElement;
    document.getElementById('box').innerHTML = '';

    observer.report();

    expect(observer.targets.has(parent)).toBe(false);
    expect(libraryRun).not.toHaveBeenCalled();
  });

  // Dialogs loaded with AJAX include the script again
  it('can be loaded twice', () => {
    const context = vm.createContext({
      window: { addEventListener: vi.fn() },
      document: { readyState: 'complete', querySelectorAll: () => [] },
    });

    vm.runInContext(scriptSource('mermaid_load.js'), context);

    expect(() => vm.runInContext(scriptSource('mermaid_load.js'), context)).not.toThrow();
  });
});
