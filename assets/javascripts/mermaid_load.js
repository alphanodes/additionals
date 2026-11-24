/* global mermaid */

// Renders mermaid diagrams (elements with class "mermaid" holding the source)
// for every plugin: window.AdditionalsMermaid.render(selector, element or list).
// The promise is fulfilled once the diagrams are drawn, so a caller can work on
// the SVG afterwards. The diagrams of the page are rendered on load.
//
// - Diagrams are drawn one after another with mermaid.render and ids of their
//   own, as Redmine core does: mermaid.run takes the SVG id from Date.now(), so
//   two calls at the same time could draw one diagram into another.
// - Mermaid.js lays out a diagram by measuring its text, which has no size while
//   the diagram is not displayed, e.g. inside a collapsed {{collapse}} macro or a
//   hidden tab: it would become an empty picture. Such a diagram is drawn once it
//   is shown (https://www.redmine.org/issues/44767).
// - The additionals configuration is added to every mermaid.initialize call by
//   additionals.js; mermaid does not render on load by itself.
(() => {
  // AJAX responses (dialogs) may include this script again
  if (window.AdditionalsMermaid) {return;}

  let renderCount = 0;
  let queue = Promise.resolve();
  const pending = new Map();
  const resolvers = new Map();

  const pageLoaded = new Promise((resolve) => {
    if (document.readyState === 'complete') {
      resolve();
    } else {
      window.addEventListener('load', resolve, { once: true });
    }
  });

  // The library may still be loading, e.g. when Redmine core and the detector
  // of redmine_reporting load it at the same time; additionals.js announces it
  const libraryLoaded = new Promise((resolve) => {
    if (typeof mermaid === 'undefined') {
      document.addEventListener('additionals:mermaid-loaded', resolve, { once: true });
    } else {
      resolve();
    }
  });

  // Same as core: the source may be indented by the markup around it
  function dedent(text) {
    const lines = text.replace(/^\n+/, '').split('\n');
    const indents = lines.filter(line => line.trim()).map(line => line.match(/^\s*/)[0].length);
    const indent = indents.length ? Math.min(...indents) : 0;
    return lines.map(line => line.slice(indent)).join('\n');
  }

  // The diagram itself may be hidden until it is rendered (stylesheets of
  // plugins hide .mermaid without data-processed), so its parent tells whether
  // it is displayed.
  function shown(node) {
    return node.parentElement?.getClientRects().length > 0;
  }

  // Redmine core (since 7.1) draws its mermaid code blocks into a div.mermaid
  // right after the <pre>, without data-processed
  function coreDiagram(node) {
    return Boolean(node.previousElementSibling?.querySelector?.('code[data-controller~="mermaid"]'));
  }

  function settle(node) {
    pending.delete(node);
    resolvers.get(node)?.();
    resolvers.delete(node);
  }

  async function drawError(node, source, error) {
    console.error('Failed to render mermaid diagram:', error);
    // mermaid.render leaves its own output in the node, mermaid.run reads the
    // source from it and shows the error in place of the diagram
    node.textContent = source;
    node.removeAttribute('data-processed');
    await mermaid.run({ nodes: [node], suppressErrors: true });
    // Without error rendering (core turns it off since Redmine 7.1) the source stays visible
    if (!node.innerHTML.trim()) {node.textContent = source;}
  }

  // Returns false if the diagram waits again to be shown
  async function draw(node) {
    // Removed or hidden again while waiting in the queue
    if (!node.isConnected) {return true;}
    if (!shown(node)) {
      waitUntilShown(node);
      return false;
    }

    const source = dedent(node.textContent).trim();
    // Displays the diagram (see shown), mermaid measures its text inside it
    node.dataset.processed = 'true';
    try {
      const { svg, bindFunctions } = await mermaid.render(`additionals-mermaid-${++renderCount}`, source, node);
      node.innerHTML = svg;
      bindFunctions?.(node);
    } catch (error) {
      await drawError(node, source, error);
    }
    return true;
  }

  // A failure of one diagram must not stop the ones queued after it
  function enqueue(node) {
    queue = queue
      .then(() => draw(node))
      .catch((error) => {
        console.error('Failed to render mermaid diagram:', error);
        return true;
      })
      .then((done) => {
        if (done) {settle(node);}
      });
  }

  // One observer for all diagrams waiting to be shown
  let visibilityObserver;
  const waiting = new Map();

  function schedule(node) {
    if (shown(node)) {
      enqueue(node);
    } else {
      waitUntilShown(node);
    }
  }

  // Diagrams removed or moved while waiting. A hidden element that is removed
  // reports no change of its size, so this runs on every render call as well.
  function releaseRemoved() {
    const moved = [];
    waiting.forEach((nodes, target) => {
      const staying = nodes.filter(node => node.isConnected && node.parentElement === target);
      nodes.forEach((node) => {
        if (!staying.includes(node)) {moved.push(node);}
      });
      if (staying.length) {
        waiting.set(target, staying);
        return;
      }

      visibilityObserver.unobserve(target);
      waiting.delete(target);
    });
    moved.forEach(node => (node.isConnected ? schedule(node) : settle(node)));
  }

  function waitUntilShown(node) {
    visibilityObserver ??= new ResizeObserver((entries) => {
      entries.forEach(({ target }) => {
        if (target.getClientRects().length === 0) {return;}

        const nodes = waiting.get(target) || [];
        visibilityObserver.unobserve(target);
        waiting.delete(target);
        nodes.forEach(enqueue);
      });
      releaseRemoved();
    });

    const parent = node.parentElement;
    if (!waiting.has(parent)) {
      waiting.set(parent, []);
      visibilityObserver.observe(parent);
    }
    waiting.get(parent).push(node);
  }

  function renderNode(node) {
    if (node.dataset.processed === 'true' || !node.parentElement || coreDiagram(node)) {return Promise.resolve();}
    if (pending.has(node)) {return pending.get(node);}

    const promise = new Promise((resolve) => { resolvers.set(node, resolve); });
    pending.set(node, promise);
    Promise.all([pageLoaded, libraryLoaded]).then(() => schedule(node));
    return promise;
  }

  async function render(target) {
    releaseRemoved();

    let nodes;
    if (typeof target === 'string') {
      nodes = document.querySelectorAll(target);
    } else if (target instanceof Element) {
      nodes = [target];
    } else {
      nodes = target;
    }
    await Promise.all(Array.from(nodes, renderNode));
  }

  if (typeof mermaid !== 'undefined') {mermaid.initialize({ startOnLoad: false });}

  window.AdditionalsMermaid = { render };

  pageLoaded.then(() => render('.mermaid:not([data-processed="true"])'));
})();
