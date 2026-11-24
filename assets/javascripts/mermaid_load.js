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
const mermaidNodeShown = node => node.parentElement?.getClientRects().length > 0;

function renderMermaidNodes(nodes) {
  const shown = [];
  nodes.forEach((node) => {
    if (mermaidNodeShown(node)) {
      shown.push(node);
      return;
    }
    if (node.dataset.mermaidWaiting || !node.parentElement) {return;}

    node.dataset.mermaidWaiting = 'true';
    // The size of the parent changes from zero when it is shown
    const observer = new ResizeObserver(() => {
      if (!mermaidNodeShown(node)) {return;}

      observer.disconnect();
      delete node.dataset.mermaidWaiting;
      renderMermaidNodes([node]);
    });
    observer.observe(node.parentElement);
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
