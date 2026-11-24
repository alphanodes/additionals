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

  // mermaid.render leaves its own output in the node: mermaid.run gets the
  // source back and shows the real error in place of the diagram
  it('shows the error of an invalid diagram through mermaid.run with its source', async () => {
    document.body.innerHTML = '<div><div class="mermaid" id="broken">graph LR\n A --></div></div>';
    const diagram = document.getElementById('broken');
    setShown(diagram, true);
    libraryRender.mockImplementationOnce((id, source, container) => {
      container.innerHTML = `<div id="d${id}"><svg></svg></div>`;
      return Promise.reject(new Error('Parse error'));
    });
    let sourceForRun;
    libraryRun.mockImplementationOnce(({ nodes }) => {
      sourceForRun = nodes[0].textContent;
      nodes[0].innerHTML = '<svg class="error"></svg>';
      return Promise.resolve();
    });
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      await render(diagram);
    } finally {
      consoleError.mockRestore();
    }

    expect(sourceForRun).toBe('graph LR\n A -->');
    expect(diagram.innerHTML).toBe('<svg class="error"></svg>');
  });

  // Redmine core turns off error rendering since 7.1
  it('keeps the source of an invalid diagram visible if mermaid shows no error', async () => {
    document.body.innerHTML = '<div><div class="mermaid" id="broken">graph LR\n A --></div></div>';
    const diagram = document.getElementById('broken');
    setShown(diagram, true);
    libraryRender.mockRejectedValueOnce(new Error('Parse error'));
    libraryRun.mockImplementationOnce(({ nodes }) => {
      nodes[0].innerHTML = '';
      nodes[0].dataset.processed = 'true';
      return Promise.resolve();
    });
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      await render(diagram);
    } finally {
      consoleError.mockRestore();
    }

    expect(diagram.textContent).toBe('graph LR\n A -->');
  });

  // A failure that escapes must not stop the diagrams queued after it
  it('draws the next diagrams after a failure', async () => {
    document.body.innerHTML = '<div><div class="mermaid" id="broken">x</div><div class="mermaid" id="next">graph LR</div></div>';
    setShown(document.getElementById('broken'), true);
    libraryRender.mockRejectedValueOnce(new Error('Parse error'));
    libraryRun.mockRejectedValueOnce(new Error('parseError handler failed'));
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      await render('#broken');
      await render('#next');
    } finally {
      consoleError.mockRestore();
    }

    expect(document.querySelector('#next svg')).not.toBeNull();
  });

  // A hidden element that is removed reports no change of its size: the next
  // render call releases it, e.g. when a preview replaces the content
  it('releases a waiting diagram whose content was replaced on the next render call', async () => {
    document.body.innerHTML = '<div id="box"><div><div class="mermaid" id="gone">graph LR</div></div></div>';
    const diagram = document.getElementById('gone');
    setShown(diagram, false);
    let released = false;

    render(diagram).then(() => { released = true; });
    await flush();
    const [observer] = observers.slice(-1);
    const parent = diagram.parentElement;
    document.getElementById('box').innerHTML = '';
    await render([]);
    await flush();

    expect(released).toBe(true);
    expect(observer.targets.has(parent)).toBe(false);
    expect(libraryRender).not.toHaveBeenCalled();
  });

  it('waits again for a diagram that is hidden again while queued', async () => {
    document.body.innerHTML = '<div><div class="mermaid" id="first">graph LR</div></div><div><div class="mermaid" id="second">graph TD</div></div>';
    const first = document.getElementById('first');
    const second = document.getElementById('second');
    setShown(first, true);
    setShown(second, true);
    let finishFirst;
    libraryRender.mockImplementationOnce(id => new Promise((done) => {
      finishFirst = () => done({ svg: `<svg id="${id}"></svg>` });
    }));

    render(first);
    render(second);
    await flush();
    setShown(second, false);
    finishFirst();
    await flush();

    expect(libraryRender.mock.calls.map(call => call[2])).toEqual([first]);
    expect([...observers.at(-1).targets]).toContain(second.parentElement);
  });

  // Dialogs loaded with AJAX include the script again
  it('can be loaded twice', () => {
    const context = vm.createContext({
      window: { addEventListener: vi.fn() },
      document: { readyState: 'complete', querySelectorAll: () => [], addEventListener: vi.fn() },
      Promise,
    });

    vm.runInContext(scriptSource('mermaid_load.js'), context);
    const api = context.window.AdditionalsMermaid;

    expect(() => vm.runInContext(scriptSource('mermaid_load.js'), context)).not.toThrow();
    expect(context.window.AdditionalsMermaid).toBe(api);
  });

  // Redmine core and the detector of redmine_reporting may load the library at
  // the same time, this script can be faster than the library
  it('waits for the library', async () => {
    const run = vi.fn(() => Promise.resolve());
    const libraryRenderLater = vi.fn(id => Promise.resolve({ svg: `<svg id="${id}"></svg>` }));
    document.body.innerHTML = '<div><div class="mermaid" id="early">graph LR</div></div>';
    const diagram = document.getElementById('early');
    setShown(diagram, true);
    const context = vm.createContext({
      window: { addEventListener: vi.fn() }, document, Element, Promise, ResizeObserver, Event, console,
    });
    vm.runInContext(scriptSource('mermaid_load.js'), context);

    const rendering = context.window.AdditionalsMermaid.render(diagram);
    await flush();

    expect(diagram.querySelector('svg')).toBeNull();

    context.mermaid = { initialize: vi.fn(), render: libraryRenderLater, run };
    document.dispatchEvent(new Event('additionals:mermaid-loaded'));
    await rendering;

    expect(libraryRenderLater).toHaveBeenCalled();
    expect(diagram.querySelector('svg')).not.toBeNull();
  });
});
