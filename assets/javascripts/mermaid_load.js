/* global globalThis, mermaid */
$(function() {
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

  mermaid.initialize({
    startOnLoad: true,
    maxTextSize: 500000,
    flowchart:{
      useMaxWidth: false
    },
    theme: mermaidTheme,
    themeVariables: mermaidThemeVariables });
});
