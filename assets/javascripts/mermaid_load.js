/* global mermaid */

// Initialize Mermaid globally. The additionals configuration is added to every
// mermaid.initialize call by additionals.js.
function initAllMermaidMacro(startOnLoad = false) {
  if (typeof mermaid === 'undefined') {return;}

  mermaid.initialize({ startOnLoad });
}

// Render a specific Mermaid macro by selector
// NOTE: If `document.readyState` is not 'complete', no extra conversion is needed because `initAllMermaidMacro` handles it.
//       However, if `document.readyState` is not 'complete', it means the element was added dynamically (e.g., via AJAX), so it should be converted separately.
/* exported renderMermaidMacro */
async function renderMermaidMacro(selector) {
  if (typeof mermaid === 'undefined' || document.readyState !== 'complete') {return;}

  /* Workaround for duplicate IDs when multiple mermaid macros are in one comment */
  /* https://github.com/redmica/redmica_ui_extension/pull/63#discussion_r1905198612 */
  await mermaid.run({ querySelector: selector, suppressErrors: true });
}

initAllMermaidMacro(true);
