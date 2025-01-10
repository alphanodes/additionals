/* global globalThis, mermaid */
var mermaidTheme;
var mermaidThemeVariables;
if (globalThis !== undefined && globalThis.mermaidTheme !== undefined) {
  mermaidTheme = globalThis.mermaidTheme;
} else {
  mermaidTheme = 'default';
}
if (globalThis !== undefined && globalThis.mermaidThemeVariables !== undefined) {
  mermaidThemeVariables = globalThis.mermaidThemeVariables;
} else {
  mermaidThemeVariables = { 'fontSize': '12px' };
}

// Initialize Mermaid globally
function initAllMermaidMacro(startOnLoad = false) {
  if (typeof mermaid === 'undefined') return;

  mermaid.initialize({
    startOnLoad: startOnLoad,
    maxTextSize: 500000,
    flowchart: {
      useMaxWidth: false
    },
    theme: mermaidTheme,
    themeVariables: mermaidThemeVariables });
}

// Render a specific Mermaid macro by selector
// NOTE: If `document.readyState` is not 'complete', no extra conversion is needed because `initAllMermaidMacro` handles it.
//       However, if `document.readyState` is not 'complete', it means the element was added dynamically (e.g., via AJAX), so it should be converted separately.
/* exported renderMermaidMacro */
async function renderMermaidMacro(selector) {
  if (typeof mermaid === 'undefined' || document.readyState !== 'complete') return;

  /* Workaround for duplicate IDs when multiple mermaid macros are in one comment */
  /* https://github.com/redmica/redmica_ui_extension/pull/63#discussion_r1905198612 */
  await mermaid.run({ querySelector: selector, suppressErrors: true});
}

initAllMermaidMacro(true);
