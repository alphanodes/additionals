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

const flush = () => new Promise((done) => { setTimeout(done, 0); });

const libraryInitialize = vi.fn();
const libraryRender = vi.fn(id => Promise.resolve({ svg: `<svg id="${id}"></svg>`, bindFunctions: vi.fn() }));
const libraryRun = vi.fn(() => Promise.resolve());

evalScript('additionals.js');
globalThis.mermaid = { initialize: libraryInitialize, render: libraryRender, run: libraryRun };
evalScript('mermaid_load.js');
// additionals.js initializes the library first, mermaid_load.js last.
// Mocks are cleared before every test.
const configOnLoad = libraryInitialize.mock.calls.at(-1)[0];
const { render } = window.AdditionalsMermaid;
const renderedIds = () => libraryRender.mock.calls.map(call => call[0]);

describe('AdditionalsMermaid', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    libraryRender.mockImplementation(id => Promise.resolve({ svg: `<svg id="${id}"></svg>`, bindFunctions: vi.fn() }));
  });

  // Rendering is left to AdditionalsMermaid, which waits for diagrams that are
  // not displayed yet
  it('does not let mermaid render on load by itself', () => {
    expect(configOnLoad.startOnLoad).toBe(false);
  });

  it('initializes mermaid with the additionals configuration', () => {
    expect(configOnLoad.maxTextSize).toBe(500000);
  });

  it('draws a diagram from its dedented source with an id of its own', async () => {
    document.body.innerHTML = '<div><div class="mermaid" id="diagram">\n    graph LR\n      A --> B\n  </div></div>';
    const diagram = document.getElementById('diagram');
    setShown(diagram, true);

    await render('#diagram');

    expect(libraryRender).toHaveBeenCalledTimes(1);
    const [id, source, container] = libraryRender.mock.calls[0];
    expect(id).toMatch(/^additionals-mermaid-\d+$/);
    expect(source).toBe('graph LR\n  A --> B');
    expect(container).toBe(diagram);
    expect(diagram.innerHTML).toBe(`<svg id="${id}"></svg>`);
    expect(diagram.dataset.processed).toBe('true');
  });

  // mermaid.run takes the id from Date.now(): diagrams rendered at the same
  // time could get the same id and one would be drawn into the other
  it('draws diagrams of calls at the same time one after another, each with its own id', async () => {
    document.body.innerHTML = '<div><div class="mermaid" id="first">graph LR</div><div class="mermaid" id="second">graph TD</div></div>';
    setShown(document.getElementById('first'), true);
    let finishFirst;
    libraryRender.mockImplementationOnce(id => new Promise((done) => {
      finishFirst = () => done({ svg: `<svg id="${id}"></svg>` });
    }));

    const both = Promise.all([render('#first'), render('#second')]);
    await flush();

    expect(libraryRender).toHaveBeenCalledTimes(1);

    finishFirst();
    await both;

    expect(libraryRender).toHaveBeenCalledTimes(2);
    expect(new Set(renderedIds()).size).toBe(2);
  });

  // A diagram in a collapsed block has no size, mermaid would lay it out as an
  // empty 16x16 picture. The promise is fulfilled once it is drawn.
  it('draws diagrams that are not displayed once they are shown', async () => {
    document.body.innerHTML = `
      <div class="collapsed-text">
        <div class="pre-wrapper"><div class="mermaid" id="first">graph LR</div></div>
        <div class="pre-wrapper"><div class="mermaid" id="second">graph TD</div></div>
      </div>`;
    const first = document.getElementById('first');
    const second = document.getElementById('second');
    setShown(first, false);
    setShown(second, false);
    let drawn = false;

    render('.mermaid').then(() => { drawn = true; });
    render('.mermaid');
    await flush();

    expect(libraryRender).not.toHaveBeenCalled();
    const [observer] = observers.slice(-1);
    expect([...observer.targets]).toEqual([first.parentElement, second.parentElement]);

    setShown(first, true);
    setShown(second, true);
    observer.report(first.parentElement, second.parentElement);
    await flush();

    expect(libraryRender.mock.calls.map(call => call[2])).toEqual([first, second]);
    expect(drawn).toBe(true);
    expect(observer.targets.size).toBe(0);
  });

  it('skips diagrams that are rendered already and diagrams of Redmine core', async () => {
    document.body.innerHTML = `
      <div><div class="mermaid" data-processed="true">done</div></div>
      <div class="pre-wrapper">
        <pre><code data-controller="mermaid">graph LR</code></pre>
        <div class="mermaid">graph LR</div>
      </div>`;
    document.querySelectorAll('.mermaid').forEach(diagram => setShown(diagram, true));

    await render('.mermaid');

    expect(libraryRender).not.toHaveBeenCalled();
  });

  it('shows the error of an invalid diagram through mermaid.run', async () => {
    document.body.innerHTML = '<div><div class="mermaid" id="broken">graph LR\n A --></div></div>';
    const diagram = document.getElementById('broken');
    setShown(diagram, true);
    libraryRender.mockRejectedValueOnce(new Error('Parse error'));
    vi.spyOn(console, 'error').mockImplementation(() => {});

    await render(diagram);

    expect(libraryRun).toHaveBeenCalledWith({ nodes: [diagram], suppressErrors: true });
    expect(diagram.dataset.processed).toBeUndefined();
  });

  it('stops waiting for a diagram whose content was replaced', async () => {
    document.body.innerHTML = '<div id="box"><div><div class="mermaid" id="gone">graph LR</div></div></div>';
    const diagram = document.getElementById('gone');
    setShown(diagram, false);

    const rendering = render(diagram);
    await flush();
    const [observer] = observers.slice(-1);
    const parent = diagram.parentElement;
    document.getElementById('box').innerHTML = '';
    observer.report();
    await rendering;

    expect(observer.targets.has(parent)).toBe(false);
    expect(libraryRender).not.toHaveBeenCalled();
  });

  // Dialogs loaded with AJAX include the script again
  it('can be loaded twice', () => {
    const context = vm.createContext({
      window: { addEventListener: vi.fn() },
      document: { readyState: 'complete', querySelectorAll: () => [] },
      Promise,
    });

    vm.runInContext(scriptSource('mermaid_load.js'), context);
    const api = context.window.AdditionalsMermaid;

    expect(() => vm.runInContext(scriptSource('mermaid_load.js'), context)).not.toThrow();
    expect(context.window.AdditionalsMermaid).toBe(api);
  });
});
