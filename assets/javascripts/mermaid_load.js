/* global mermaid */

// Initialize Mermaid globally. The additionals configuration is added to every
// mermaid.initialize call by additionals.js. The diagrams of the page are
// rendered on load below, not by mermaid itself, which would render the ones
// that are not displayed as well.
function initAllMermaidMacro() {
  if (typeof mermaid === 'undefined') {return;}

  mermaid.initialize({ startOnLoad: false });
}

// Mermaid.js lays out a diagram by measuring its text, which has no size while
// the diagram is not displayed, e.g. inside a collapsed {{collapse}} macro or a
// hidden tab: it would become an empty picture. Such a diagram is rendered once
// it is shown, as Redmine core does with its mermaid code blocks since 7.1
// (https://www.redmine.org/issues/44767).
// The diagram itself may be hidden until it is rendered (stylesheets of
// plugins hide .mermaid without data-processed), so its parent tells whether
// it is displayed.
function mermaidNodeShown(node) {
  return node.parentElement?.getClientRects().length > 0;
}

// One observer for all diagrams waiting to be shown. The diagrams shown at the
// same time (e.g. in one collapsed block) are rendered by one mermaid.run
// call: mermaid takes the SVG id from Date.now(), so two calls at the same time
// can give two diagrams the same id and draw one into the other.
function mermaidVisibilityObserver() {
  if (renderMermaidNodes.visibilityObserver) {return renderMermaidNodes.visibilityObserver;}

  const watched = new Set();
  const observer = new ResizeObserver((entries) => {
    const nodes = [];
    entries.forEach(({ target }) => {
      if (target.getClientRects().length === 0) {return;}

      observer.unobserve(target);
      watched.delete(target);
      target.querySelectorAll(':scope > [data-mermaid-waiting]').forEach((node) => {
        delete node.dataset.mermaidWaiting;
        nodes.push(node);
      });
    });
    // Content replaced while hidden: nothing left to wait for
    watched.forEach((target) => {
      if (target.isConnected) {return;}

      observer.unobserve(target);
      watched.delete(target);
    });
    renderMermaidNodes(nodes);
  });
  observer.watch = (target) => {
    watched.add(target);
    observer.observe(target);
  };
  renderMermaidNodes.visibilityObserver = observer;
  return observer;
}

function renderMermaidNodes(nodes) {
  const shown = [];
  nodes.forEach((node) => {
    if (node.dataset.processed === 'true' || node.dataset.mermaidWaiting) {return;}

    if (mermaidNodeShown(node)) {
      shown.push(node);
    } else if (node.parentElement) {
      node.dataset.mermaidWaiting = 'true';
      mermaidVisibilityObserver().watch(node.parentElement);
    }
  });

  if (shown.length === 0) {return Promise.resolve();}

  return mermaid.run({ nodes: shown, suppressErrors: true });
}

// Render a specific Mermaid macro by selector
// NOTE: If `document.readyState` is not 'complete', no extra conversion is needed because the load handler below handles it.
//       However, if `document.readyState` is 'complete', it means the element was added dynamically (e.g., via AJAX), so it should be converted separately.
/* exported renderMermaidMacro */
async function renderMermaidMacro(selector) {
  if (typeof mermaid === 'undefined' || document.readyState !== 'complete') {return;}

  /* Workaround for duplicate IDs when multiple mermaid macros are in one comment */
  /* https://github.com/redmica/redmica_ui_extension/pull/63#discussion_r1905198612 */
  await renderMermaidNodes([...document.querySelectorAll(selector)]);
}

initAllMermaidMacro();
// As mermaid's startOnLoad did: all diagrams of the page once it is loaded
window.addEventListener('load', () => {
  if (typeof mermaid === 'undefined') {return;}

  renderMermaidNodes([...document.querySelectorAll('.mermaid:not([data-processed="true"])')]);
});
