/* global mermaid */

// Initialize Mermaid globally
// theme, themeVariables, look and layout are only passed on when a theme sets
// them (globalThis.mermaidTheme, ...), so mermaid's own per diagram defaults
// (ELK layout, neo look, redux-color theme) apply otherwise.
function initAllMermaidMacro(startOnLoad = false) {
  if (typeof mermaid === 'undefined') {return;}

  const config = {
    startOnLoad,
    maxTextSize: 500000,
    flowchart: {
      useMaxWidth: false,
    },
    gantt: {
      topAxis: true,
      weekday: 'monday',
    },
  };

  if (globalThis.mermaidTheme !== undefined) {config.theme = globalThis.mermaidTheme;}
  if (globalThis.mermaidThemeVariables !== undefined) {config.themeVariables = globalThis.mermaidThemeVariables;}
  if (globalThis.mermaidLook !== undefined) {config.look = globalThis.mermaidLook;}
  if (globalThis.mermaidLayout !== undefined) {config.layout = globalThis.mermaidLayout;}

  mermaid.initialize(config);
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
